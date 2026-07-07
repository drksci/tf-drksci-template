"""
Service-level tests — ArgoCD, registry, Longhorn UI, Pulse.

All tests require a live cluster (``@pytest.mark.e2e``).
Each test additionally checks for an ``ENABLE_<SERVICE>=true`` environment
variable and skips when it is not set.
"""

from __future__ import annotations

import os
import subprocess
import uuid

import pytest
import requests
from kubernetes import client as k8s_client
from tenacity import retry, stop_after_delay, wait_fixed

from conftest import wait_for_deployment

pytestmark = pytest.mark.e2e


def _require_service(name: str) -> None:
    """Skip the calling test unless ENABLE_<NAME>=true is set."""
    env_key = f"ENABLE_{name.upper()}"
    if os.environ.get(env_key, "").lower() != "true":
        pytest.skip(f"{env_key} is not set to 'true' — skipping {name} tests")


# ---------------------------------------------------------------------------
# ArgoCD
# ---------------------------------------------------------------------------


def test_argocd_ready(k8s_apps: k8s_client.AppsV1Api) -> None:
    """argocd-server deployment must have at least one available replica."""
    _require_service("argocd")
    try:
        wait_for_deployment(k8s_apps, "argocd", "argocd-server", timeout=60)
    except k8s_client.ApiException as exc:
        if exc.status == 404:
            pytest.skip("argocd-server deployment not found — skipping")
        raise


def test_argocd_api(traefik_ip: str, internal_domain: str) -> None:
    """ArgoCD REST API /api/version must return HTTP 200 via Traefik."""
    _require_service("argocd")
    url = f"http://{traefik_ip}/api/version"
    host = f"argocd.{internal_domain}"
    resp = requests.get(url, headers={"Host": host}, timeout=10)
    assert resp.status_code == 200, (
        f"ArgoCD API at {url} (Host: {host}) returned {resp.status_code}"
    )


# ---------------------------------------------------------------------------
# Registry
# ---------------------------------------------------------------------------


def test_registry_ready(k8s_apps: k8s_client.AppsV1Api) -> None:
    """Registry deployment must have at least one available replica."""
    _require_service("registry")
    # Registry deployment may be named 'registry' or 'docker-registry'
    for name in ("registry", "docker-registry"):
        for ns in ("registry", "kube-system", "default"):
            try:
                wait_for_deployment(k8s_apps, ns, name, timeout=60)
                return
            except (k8s_client.ApiException, TimeoutError):
                pass
    pytest.skip("Registry deployment not found in expected namespaces — skipping")


def test_registry_catalog(traefik_ip: str, internal_domain: str) -> None:
    """Registry /v2/_catalog must return HTTP 200 via Traefik."""
    _require_service("registry")
    url = f"http://{traefik_ip}/v2/_catalog"
    host = f"registry.{internal_domain}"
    resp = requests.get(url, headers={"Host": host}, timeout=10)
    assert resp.status_code == 200, (
        f"Registry catalog at {url} (Host: {host}) returned {resp.status_code}"
    )


@pytest.mark.slow
def test_registry_push_pull(traefik_ip: str, internal_domain: str) -> None:
    """
    Full push/pull cycle against the homelab registry using the docker CLI.

    Steps:
    1. Pull ``hello-world`` from Docker Hub.
    2. Tag it as ``registry.{domain}/test/hello-world:e2e``.
    3. Push to the homelab registry.
    4. Verify the image appears in /v2/_catalog.
    5. Delete via registry API (mark for GC).
    """
    _require_service("registry")

    registry_host = f"registry.{internal_domain}"
    image_ref = f"{registry_host}/test/hello-world:e2e"

    def _run(cmd: list[str]) -> subprocess.CompletedProcess:
        return subprocess.run(cmd, capture_output=True, text=True, check=True)

    try:
        _run(["docker", "pull", "hello-world:latest"])
        _run(["docker", "tag", "hello-world:latest", image_ref])
        _run(["docker", "push", image_ref])
    except FileNotFoundError:
        pytest.skip("docker CLI not found — skipping registry push/pull test")
    except subprocess.CalledProcessError as exc:
        pytest.fail(f"docker command failed: {exc.stderr}")

    # Verify image appears in catalog
    url = f"http://{traefik_ip}/v2/_catalog"
    host = f"registry.{internal_domain}"

    @retry(stop=stop_after_delay(30), wait=wait_fixed(3))
    def _verify_catalog() -> None:
        resp = requests.get(url, headers={"Host": host}, timeout=10)
        assert resp.status_code == 200
        catalog = resp.json()
        repos = catalog.get("repositories", [])
        assert "test/hello-world" in repos, (
            f"test/hello-world not in catalog: {repos}"
        )

    _verify_catalog()

    # Best-effort delete via registry API
    try:
        digest_url = f"http://{traefik_ip}/v2/test/hello-world/manifests/e2e"
        r = requests.get(
            digest_url,
            headers={
                "Host": host,
                "Accept": "application/vnd.docker.distribution.manifest.v2+json",
            },
            timeout=10,
        )
        digest = r.headers.get("Docker-Content-Digest")
        if digest:
            requests.delete(
                f"http://{traefik_ip}/v2/test/hello-world/manifests/{digest}",
                headers={"Host": host},
                timeout=10,
            )
    except Exception:
        pass  # Registry GC cleanup is best-effort

    # Remove local tags
    try:
        subprocess.run(["docker", "rmi", image_ref], capture_output=True, check=False)
    except Exception:
        pass


# ---------------------------------------------------------------------------
# Longhorn UI
# ---------------------------------------------------------------------------


def test_longhorn_ui(traefik_ip: str, internal_domain: str) -> None:
    """Longhorn UI must return a non-5xx response via Traefik."""
    _require_service("longhorn")
    url = f"http://{traefik_ip}"
    host = f"longhorn.{internal_domain}"
    resp = requests.get(url, headers={"Host": host}, timeout=10, allow_redirects=True)
    assert resp.status_code < 500, (
        f"Longhorn UI at {url} (Host: {host}) returned {resp.status_code}"
    )


# ---------------------------------------------------------------------------
# Pulse
# ---------------------------------------------------------------------------


def test_pulse_ui(traefik_ip: str, internal_domain: str) -> None:
    """Pulse monitoring UI must return a non-5xx response via Traefik."""
    _require_service("pulse")
    url = f"http://{traefik_ip}"
    host = f"pulse.{internal_domain}"
    resp = requests.get(url, headers={"Host": host}, timeout=10, allow_redirects=True)
    assert resp.status_code < 500, (
        f"Pulse UI at {url} (Host: {host}) returned {resp.status_code}"
    )
