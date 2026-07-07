"""
Cluster health tests.

All tests require a live cluster (``@pytest.mark.e2e``).  They skip
automatically when the cluster is unreachable via the ``cluster_available``
fixture defined in conftest.py.
"""

from __future__ import annotations

import pytest
from kubernetes import client as k8s_client
from tenacity import retry, stop_after_delay, wait_fixed

pytestmark = pytest.mark.e2e


# ---------------------------------------------------------------------------
# Node health
# ---------------------------------------------------------------------------


def test_nodes_ready(k8s_core: k8s_client.CoreV1Api) -> None:
    """Every cluster node must have condition type=Ready status=True."""
    nodes = k8s_core.list_node().items
    assert nodes, "No nodes found in the cluster"

    not_ready = []
    for node in nodes:
        for condition in node.status.conditions or []:
            if condition.type == "Ready" and condition.status != "True":
                not_ready.append(node.metadata.name)

    assert not not_ready, f"Nodes not Ready: {not_ready}"


# ---------------------------------------------------------------------------
# kube-system pods
# ---------------------------------------------------------------------------


def test_kube_system_healthy(k8s_core: k8s_client.CoreV1Api) -> None:
    """All pods in kube-system must be Running or Succeeded."""
    pods = k8s_core.list_namespaced_pod("kube-system").items
    assert pods, "No pods found in kube-system"

    bad_pods = []
    for pod in pods:
        phase = pod.status.phase
        if phase not in ("Running", "Succeeded"):
            bad_pods.append(f"{pod.metadata.name} ({phase})")
            continue

        # Also check container statuses for CrashLoopBackOff
        for cs in pod.status.container_statuses or []:
            waiting = cs.state.waiting
            if waiting and waiting.reason in (
                "CrashLoopBackOff",
                "Error",
                "OOMKilled",
            ):
                bad_pods.append(
                    f"{pod.metadata.name}/{cs.name} ({waiting.reason})"
                )

    assert not bad_pods, f"Unhealthy pods in kube-system: {bad_pods}"


# ---------------------------------------------------------------------------
# Traefik
# ---------------------------------------------------------------------------


def test_traefik_running(
    k8s_apps: k8s_client.AppsV1Api,
    k8s_core: k8s_client.CoreV1Api,
) -> None:
    """Traefik deployment must be available and its Service must have an LB IP."""
    # Find Traefik deployment — it may live in 'traefik' or 'kube-system'
    deploy = None
    for ns in ("traefik", "kube-system"):
        try:
            deploy = k8s_apps.read_namespaced_deployment("traefik", ns)
            traefik_ns = ns
            break
        except k8s_client.ApiException as exc:
            if exc.status != 404:
                raise

    assert deploy is not None, (
        "Traefik deployment not found in namespaces 'traefik' or 'kube-system'"
    )
    available = deploy.status.available_replicas or 0
    assert available >= 1, (
        f"Traefik deployment has {available} available replicas"
    )

    # Verify LoadBalancer Service has an ingress IP
    svc = k8s_core.read_namespaced_service("traefik", traefik_ns)
    ingress = (svc.status.load_balancer.ingress or [])
    assert ingress, "Traefik Service has no LoadBalancer ingress IP/hostname"
    ip = ingress[0].ip or ingress[0].hostname
    assert ip, "Traefik LoadBalancer ingress entry has neither ip nor hostname"


# ---------------------------------------------------------------------------
# k3s secrets encryption (informational)
# ---------------------------------------------------------------------------


@pytest.mark.xfail(
    reason=(
        "Secrets-encryption flag cannot be verified remotely via the API. "
        "Confirm /etc/rancher/k3s/server/crypt.json exists on the server node."
    ),
    strict=False,
)
def test_k3s_secrets_encryption_flag(k8s_core: k8s_client.CoreV1Api) -> None:
    """
    Verify that secrets-at-rest encryption is enabled on the k3s server.

    k3s does not surface the --secrets-encryption flag through any API object,
    so this test checks for the annotation that the k3s bootstrap TF module
    writes to the kube-system namespace, or else marks xfail.
    """
    ns = k8s_core.read_namespace("kube-system")
    annotations = ns.metadata.annotations or {}
    labels = ns.metadata.labels or {}

    secrets_enc = (
        annotations.get("homelab.drksci.local/secrets-encryption") == "true"
        or labels.get("homelab.drksci.local/secrets-encryption") == "true"
    )
    assert secrets_enc, (
        "secrets-encryption annotation not found on kube-system namespace. "
        "Manually confirm --secrets-encryption is passed to k3s server."
    )


# ---------------------------------------------------------------------------
# Longhorn
# ---------------------------------------------------------------------------


def test_longhorn_system_healthy(k8s_apps: k8s_client.AppsV1Api) -> None:
    """Longhorn-manager DaemonSet must have desired == ready replicas."""
    try:
        ds = k8s_apps.read_namespaced_daemon_set(
            "longhorn-manager", "longhorn-system"
        )
    except k8s_client.ApiException as exc:
        if exc.status == 404:
            pytest.skip("Longhorn is not installed — skipping Longhorn health check")
        raise

    desired = ds.status.desired_number_scheduled or 0
    ready = ds.status.number_ready or 0
    assert desired > 0, "Longhorn DaemonSet has 0 desired pods"
    assert ready == desired, (
        f"Longhorn DaemonSet: {ready} ready out of {desired} desired"
    )
