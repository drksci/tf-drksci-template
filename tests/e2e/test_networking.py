"""
Networking tests — IngressRoutes, DNS, and in-cluster connectivity.

All tests require a live cluster (``@pytest.mark.e2e``).
"""

from __future__ import annotations

import time
import uuid

import pytest
import requests
from kubernetes import client as k8s_client
from tenacity import retry, stop_after_delay, wait_fixed

pytestmark = pytest.mark.e2e


# ---------------------------------------------------------------------------
# IngressRoute CRDs
# ---------------------------------------------------------------------------


def test_ingressroutes_exist(k8s_custom: k8s_client.CustomObjectsApi) -> None:
    """At least one Traefik IngressRoute must exist in the cluster."""
    try:
        result = k8s_custom.list_cluster_custom_object(
            group="traefik.io",
            version="v1alpha1",
            plural="ingressroutes",
        )
    except k8s_client.ApiException as exc:
        # Older Traefik versions use traefik.containo.us
        if exc.status in (404, 405):
            try:
                result = k8s_custom.list_cluster_custom_object(
                    group="traefik.containo.us",
                    version="v1alpha1",
                    plural="ingressroutes",
                )
            except k8s_client.ApiException as exc2:
                if exc2.status in (404, 405):
                    pytest.skip("IngressRoute CRD not installed — skipping")
                raise
        else:
            raise

    items = result.get("items", [])
    assert items, "No IngressRoutes found — expected at least one"


# ---------------------------------------------------------------------------
# MinIO reachability via Traefik
# ---------------------------------------------------------------------------


def test_minio_reachable_via_traefik(traefik_ip: str, internal_domain: str) -> None:
    """MinIO health endpoint must return 200 via the Traefik LB."""
    url = f"http://{traefik_ip}/minio/health/live"
    host = f"minio.{internal_domain}"
    resp = requests.get(url, headers={"Host": host}, timeout=10)
    assert resp.status_code == 200, (
        f"MinIO health/live at {url} (Host: {host}) returned {resp.status_code}"
    )


# ---------------------------------------------------------------------------
# In-cluster DNS via temporary busybox pod (slow)
# ---------------------------------------------------------------------------


@pytest.mark.slow
def test_in_cluster_minio_dns(k8s_core: k8s_client.CoreV1Api) -> None:
    """
    Spawn a busybox pod to run nslookup against minio.minio.svc.cluster.local
    and verify an IP address is returned.

    This confirms that the headless Service + Endpoints routing for the
    Docker-Compose MinIO is wired correctly inside the cluster.
    """
    pod_name = f"e2e-dns-{uuid.uuid4().hex[:8]}"
    namespace = "default"
    target = "minio.minio.svc.cluster.local"

    pod_body = k8s_client.V1Pod(
        metadata=k8s_client.V1ObjectMeta(
            name=pod_name,
            labels={"created-by": "homelab-e2e"},
        ),
        spec=k8s_client.V1PodSpec(
            restart_policy="Never",
            containers=[
                k8s_client.V1Container(
                    name="dns-check",
                    image="busybox:1.36",
                    command=["nslookup", target],
                )
            ],
        ),
    )

    k8s_core.create_namespaced_pod(namespace, pod_body)

    try:
        # Wait for pod to complete (up to 90 s)
        @retry(stop=stop_after_delay(90), wait=wait_fixed(5))
        def _wait_done() -> None:
            pod = k8s_core.read_namespaced_pod(pod_name, namespace)
            phase = pod.status.phase
            if phase not in ("Succeeded", "Failed"):
                raise RuntimeError(f"Pod {pod_name} phase={phase}")

        _wait_done()

        pod = k8s_core.read_namespaced_pod(pod_name, namespace)
        assert pod.status.phase == "Succeeded", (
            f"DNS lookup pod exited with phase={pod.status.phase}"
        )

        # Read logs to verify an IP was returned
        logs = k8s_core.read_namespaced_pod_log(pod_name, namespace)
        assert any(
            part.replace(".", "").isdigit()
            for line in logs.splitlines()
            for part in line.split()
            if "." in part and len(part) > 6
        ), (
            f"nslookup output does not contain an IP address:\n{logs}"
        )

    finally:
        try:
            k8s_core.delete_namespaced_pod(pod_name, namespace)
        except Exception:
            pass


# ---------------------------------------------------------------------------
# dnsmasq stack detection
# ---------------------------------------------------------------------------


def test_dnsmasq_stack_present(k8s_core: k8s_client.CoreV1Api) -> None:
    """
    Check that the dnsmasq DNS stack has some cluster presence.

    dnsmasq is managed as a Docker Compose stack (Dockge), so it may not
    have a k8s Service.  We accept any of:
    - a pod with 'dnsmasq' in its name
    - a ConfigMap with 'dnsmasq' in its name
    - a namespace called 'dnsmasq' or 'dns'

    Skip if nothing is found (cluster may not deploy the DNS module).
    """
    # Check namespaces
    ns_names = {ns.metadata.name for ns in k8s_core.list_namespace().items}
    if any("dns" in n for n in ns_names):
        return  # Found a dns-related namespace

    # Check ConfigMaps cluster-wide
    cms = k8s_core.list_config_map_for_all_namespaces()
    for cm in cms.items:
        if "dnsmasq" in cm.metadata.name.lower():
            return

    # Check pods cluster-wide
    pods = k8s_core.list_pod_for_all_namespaces()
    for pod in pods.items:
        if "dnsmasq" in pod.metadata.name.lower():
            return

    pytest.skip(
        "dnsmasq stack not detectable in-cluster — "
        "it may be running as a Docker Compose stack outside k8s."
    )
