"""
Storage tests — MinIO S3 and Longhorn PVC provisioning.

All tests require a live cluster (``@pytest.mark.e2e``).
"""

from __future__ import annotations

import uuid

import pytest
import requests
from kubernetes import client as k8s_client
from tenacity import retry, stop_after_delay, wait_fixed

pytestmark = pytest.mark.e2e

_TEST_CONTENT = b"homelab-e2e-test-object-content"


# ---------------------------------------------------------------------------
# MinIO — HTTP reachability via Traefik
# ---------------------------------------------------------------------------


def test_minio_console_reachable(traefik_ip: str, internal_domain: str) -> None:
    """MinIO console must return a non-5xx response via Traefik."""
    url = f"http://{traefik_ip}"
    host = f"minio.{internal_domain}"
    resp = requests.get(url, headers={"Host": host}, timeout=10, allow_redirects=True)
    assert resp.status_code < 500, (
        f"MinIO console at {url} (Host: {host}) returned HTTP {resp.status_code}"
    )


def test_minio_auth_required(traefik_ip: str, internal_domain: str) -> None:
    """Unauthenticated S3 API requests must be rejected (403 or 400, not 200)."""
    url = f"http://{traefik_ip}/"
    host = f"s3.{internal_domain}"
    resp = requests.get(url, headers={"Host": host}, timeout=10)
    assert resp.status_code in (400, 403), (
        f"Expected 400 or 403 from unauthenticated S3 API, got {resp.status_code}"
    )


# ---------------------------------------------------------------------------
# MinIO — S3 API via boto3
# ---------------------------------------------------------------------------


def test_minio_s3_list_buckets(minio_s3) -> None:
    """list_buckets() must complete without error."""
    response = minio_s3.list_buckets()
    assert "Buckets" in response


def test_minio_s3_crud(minio_s3) -> None:
    """Create bucket → put object → get and verify → delete object → delete bucket."""
    bucket = f"e2e-test-{uuid.uuid4().hex[:12]}"
    key = "smoke/test-object.txt"

    try:
        minio_s3.create_bucket(Bucket=bucket)

        minio_s3.put_object(Bucket=bucket, Key=key, Body=_TEST_CONTENT)

        @retry(stop=stop_after_delay(30), wait=wait_fixed(2))
        def _get_and_verify() -> None:
            obj = minio_s3.get_object(Bucket=bucket, Key=key)
            body = obj["Body"].read()
            assert body == _TEST_CONTENT, (
                f"Object content mismatch: expected {_TEST_CONTENT!r}, got {body!r}"
            )

        _get_and_verify()

    finally:
        # Best-effort cleanup so we never leave orphaned buckets
        try:
            minio_s3.delete_object(Bucket=bucket, Key=key)
        except Exception:
            pass
        try:
            minio_s3.delete_bucket(Bucket=bucket)
        except Exception:
            pass


# ---------------------------------------------------------------------------
# Longhorn — StorageClass
# ---------------------------------------------------------------------------


def test_longhorn_storageclass_default(k8s_core: k8s_client.CoreV1Api) -> None:
    """StorageClass 'longhorn' must exist and be annotated as default."""
    storage_api = k8s_client.StorageV1Api()
    try:
        sc = storage_api.read_storage_class("longhorn")
    except k8s_client.ApiException as exc:
        if exc.status == 404:
            pytest.skip("Longhorn StorageClass not found — skipping")
        raise

    annotations = sc.metadata.annotations or {}
    is_default = annotations.get("storageclass.kubernetes.io/is-default-class")
    assert is_default == "true", (
        "Longhorn StorageClass exists but is not annotated as the default "
        f"(storageclass.kubernetes.io/is-default-class={is_default!r})"
    )


def test_longhorn_recurring_jobs(k8s_custom: k8s_client.CustomObjectsApi) -> None:
    """RecurringJob CRDs 'daily-snapshot' and 'weekly-backup' must exist in longhorn-system."""
    group = "longhorn.io"
    version = "v1beta2"
    plural = "recurringjobs"

    try:
        jobs = k8s_custom.list_namespaced_custom_object(
            group, version, "longhorn-system", plural
        )
    except k8s_client.ApiException as exc:
        if exc.status in (404, 405):
            pytest.skip("Longhorn RecurringJob CRD not present — skipping")
        raise

    job_names = {item["metadata"]["name"] for item in jobs.get("items", [])}
    missing = {"daily-snapshot", "weekly-backup"} - job_names
    assert not missing, f"Missing Longhorn RecurringJobs: {missing}"


# ---------------------------------------------------------------------------
# Longhorn — PVC provision (slow)
# ---------------------------------------------------------------------------


@pytest.mark.slow
def test_pvc_provision_and_delete(k8s_core: k8s_client.CoreV1Api) -> None:
    """
    Provision a 1Gi PVC using the 'longhorn' StorageClass, wait for Bound,
    then delete it.  Full cleanup runs even if the assertion fails.
    """
    storage_api = k8s_client.StorageV1Api()
    try:
        storage_api.read_storage_class("longhorn")
    except k8s_client.ApiException as exc:
        if exc.status == 404:
            pytest.skip("Longhorn StorageClass not found — skipping PVC test")
        raise

    pvc_name = f"e2e-test-{uuid.uuid4().hex[:8]}"
    namespace = "default"

    pvc_body = k8s_client.V1PersistentVolumeClaim(
        metadata=k8s_client.V1ObjectMeta(
            name=pvc_name,
            labels={"created-by": "homelab-e2e"},
        ),
        spec=k8s_client.V1PersistentVolumeClaimSpec(
            access_modes=["ReadWriteOnce"],
            storage_class_name="longhorn",
            resources=k8s_client.V1VolumeResourceRequirements(
                requests={"storage": "1Gi"}
            ),
        ),
    )

    k8s_core.create_namespaced_persistent_volume_claim(namespace, pvc_body)

    try:
        @retry(stop=stop_after_delay(60), wait=wait_fixed(5))
        def _wait_bound() -> None:
            pvc = k8s_core.read_namespaced_persistent_volume_claim(pvc_name, namespace)
            if pvc.status.phase != "Bound":
                raise RuntimeError(f"PVC {pvc_name} phase={pvc.status.phase}")

        _wait_bound()

    finally:
        try:
            k8s_core.delete_namespaced_persistent_volume_claim(pvc_name, namespace)
        except Exception:
            pass
