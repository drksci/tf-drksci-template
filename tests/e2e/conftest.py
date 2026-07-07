"""
Shared fixtures for homelab end-to-end tests.

All e2e fixtures are session-scoped so the cluster connection is
established once per pytest run. If the API server is unreachable
every test decorated with @pytest.mark.e2e skips gracefully.
"""

from __future__ import annotations

import os
from pathlib import Path

import boto3
import pytest
import requests
from botocore.config import Config
from kubernetes import client as k8s_client
from kubernetes import config as k8s_config
from tenacity import retry, stop_after_delay, wait_fixed


# ---------------------------------------------------------------------------
# Cluster availability gate
# ---------------------------------------------------------------------------


@pytest.fixture(scope="session")
def cluster_available() -> None:
    """
    Attempt to reach the Kubernetes API server.

    If the server is not reachable this fixture calls pytest.skip so that
    every downstream fixture and test skips rather than errors out.
    """
    kubeconfig_path = os.environ.get(
        "KUBECONFIG", str(Path.home() / ".kube" / "homelab.yaml")
    )

    try:
        if os.path.isfile(kubeconfig_path):
            k8s_config.load_kube_config(config_file=kubeconfig_path)
        else:
            k8s_config.load_kube_config()

        core = k8s_client.CoreV1Api()
        core.list_namespace(_request_timeout=(5, 10))
    except Exception as exc:
        pytest.skip(
            f"Kubernetes cluster not reachable — skipping all e2e tests. "
            f"Set KUBECONFIG to a valid kubeconfig or start the cluster. "
            f"Error: {exc}"
        )


# ---------------------------------------------------------------------------
# Kubernetes API clients
# ---------------------------------------------------------------------------


@pytest.fixture(scope="session")
def k8s_core(cluster_available) -> k8s_client.CoreV1Api:
    """CoreV1Api client (pods, nodes, services, PVCs, …)."""
    return k8s_client.CoreV1Api()


@pytest.fixture(scope="session")
def k8s_apps(cluster_available) -> k8s_client.AppsV1Api:
    """AppsV1Api client (deployments, daemonsets, …)."""
    return k8s_client.AppsV1Api()


@pytest.fixture(scope="session")
def k8s_custom(cluster_available) -> k8s_client.CustomObjectsApi:
    """CustomObjectsApi client for CRD checks (IngressRoutes, Longhorn, Velero)."""
    return k8s_client.CustomObjectsApi()


# ---------------------------------------------------------------------------
# Network helpers
# ---------------------------------------------------------------------------


@pytest.fixture(scope="session")
def traefik_ip(k8s_core: k8s_client.CoreV1Api) -> str:
    """
    Resolve the Traefik LoadBalancer IP.

    Search order:
    1. ``TRAEFIK_IP`` environment variable.
    2. Service ``traefik`` in namespace ``traefik``.
    3. Service ``traefik`` in namespace ``kube-system``.
    """
    env_ip = os.environ.get("TRAEFIK_IP", "").strip()
    if env_ip:
        return env_ip

    for namespace in ("traefik", "kube-system"):
        try:
            svc = k8s_core.read_namespaced_service("traefik", namespace)
            ingress = (svc.status.load_balancer.ingress or [])
            if ingress:
                ip = ingress[0].ip or ingress[0].hostname
                if ip:
                    return ip
        except k8s_client.ApiException:
            pass

    pytest.skip(
        "Cannot determine Traefik LoadBalancer IP. "
        "Set TRAEFIK_IP env var or ensure the Traefik service is provisioned."
    )


@pytest.fixture(scope="session")
def internal_domain() -> str:
    """Return the base domain for internal services (default: drksci.local)."""
    return os.environ.get("INTERNAL_DOMAIN", "drksci.local")


# ---------------------------------------------------------------------------
# S3 / MinIO client
# ---------------------------------------------------------------------------


@pytest.fixture(scope="session")
def minio_s3(cluster_available, internal_domain: str):
    """
    Boto3 S3 client pointed at MinIO via Traefik.

    Credentials are read from environment variables:
    - ``MINIO_ROOT_USER``     (default: ``admin``)
    - ``MINIO_ROOT_PASSWORD`` (required — skip if absent)

    The endpoint is ``http://s3.{internal_domain}``.  Traffic is routed by
    Traefik using SNI / Host-header matching.
    """
    access_key = os.environ.get("MINIO_ROOT_USER", "admin")
    secret_key = os.environ.get("MINIO_ROOT_PASSWORD", "")

    if not secret_key:
        pytest.skip(
            "MINIO_ROOT_PASSWORD env var not set — skipping MinIO S3 fixtures."
        )

    endpoint = f"http://s3.{internal_domain}"

    # Verify endpoint is reachable before handing the client to tests.
    try:
        requests.get(endpoint, timeout=5)
    except requests.exceptions.ConnectionError as exc:
        pytest.skip(f"MinIO endpoint {endpoint!r} not reachable: {exc}")

    return boto3.client(
        "s3",
        endpoint_url=endpoint,
        aws_access_key_id=access_key,
        aws_secret_access_key=secret_key,
        config=Config(signature_version="s3v4"),
        region_name="us-east-1",
    )


# ---------------------------------------------------------------------------
# Utility helpers
# ---------------------------------------------------------------------------


def wait_for_deployment(
    apps_client: k8s_client.AppsV1Api,
    namespace: str,
    name: str,
    timeout: int = 120,
) -> None:
    """
    Poll until a Deployment has at least one available replica.

    Raises ``TimeoutError`` if the deployment does not become available within
    *timeout* seconds.
    """

    @retry(stop=stop_after_delay(timeout), wait=wait_fixed(5))
    def _check() -> None:
        deploy = apps_client.read_namespaced_deployment(name, namespace)
        available = deploy.status.available_replicas or 0
        if available < 1:
            raise RuntimeError(
                f"Deployment {namespace}/{name} has {available} available replicas"
            )

    try:
        _check()
    except Exception as exc:
        raise TimeoutError(
            f"Deployment {namespace}/{name} did not become available "
            f"within {timeout}s: {exc}"
        ) from exc
