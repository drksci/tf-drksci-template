"""
Backup infrastructure tests — Velero schedules and MinIO backup bucket.

All tests require a live cluster (``@pytest.mark.e2e``) and additionally
skip unless ``ENABLE_BACKUP=true`` is set in the environment.
"""

from __future__ import annotations

import os

import pytest
from kubernetes import client as k8s_client

from conftest import wait_for_deployment

pytestmark = pytest.mark.e2e


def _require_backup() -> None:
    if os.environ.get("ENABLE_BACKUP", "").lower() != "true":
        pytest.skip("ENABLE_BACKUP is not set to 'true' — skipping backup tests")


# ---------------------------------------------------------------------------
# Velero deployment
# ---------------------------------------------------------------------------


def test_velero_ready(k8s_apps: k8s_client.AppsV1Api) -> None:
    """Velero deployment in namespace 'velero' must have at least one available replica."""
    _require_backup()
    try:
        wait_for_deployment(k8s_apps, "velero", "velero", timeout=60)
    except k8s_client.ApiException as exc:
        if exc.status == 404:
            pytest.fail(
                "ENABLE_BACKUP=true but velero deployment not found in namespace 'velero'"
            )
        raise


# ---------------------------------------------------------------------------
# Velero Schedule CRD
# ---------------------------------------------------------------------------


def test_backup_schedule_exists(k8s_custom: k8s_client.CustomObjectsApi) -> None:
    """At least one Velero Schedule CRD must exist when backups are enabled."""
    _require_backup()
    try:
        result = k8s_custom.list_namespaced_custom_object(
            group="velero.io",
            version="v1",
            namespace="velero",
            plural="schedules",
        )
    except k8s_client.ApiException as exc:
        if exc.status in (404, 405):
            pytest.fail(
                "ENABLE_BACKUP=true but Velero Schedule CRD not registered — "
                "is Velero installed?"
            )
        raise

    items = result.get("items", [])
    assert items, "No Velero Schedules found — expected at least one backup schedule"


# ---------------------------------------------------------------------------
# Retention detector CronJob
# ---------------------------------------------------------------------------


def test_retention_detector_cronjob(k8s_core: k8s_client.CoreV1Api) -> None:
    """CronJob 'retention-detector' must exist in any namespace."""
    _require_backup()
    batch_api = k8s_client.BatchV1Api()
    all_cjs = batch_api.list_cron_job_for_all_namespaces()

    found = any(
        cj.metadata.name == "retention-detector"
        for cj in all_cjs.items
    )
    assert found, (
        "CronJob 'retention-detector' not found in any namespace. "
        "Check that the retention-detector module is deployed."
    )


# ---------------------------------------------------------------------------
# MinIO backup bucket
# ---------------------------------------------------------------------------


def test_minio_backup_bucket_accessible(minio_s3) -> None:
    """
    The Velero-managed backup bucket ('velero' or 'backups') must be present
    in the MinIO S3 listing.
    """
    _require_backup()
    response = minio_s3.list_buckets()
    bucket_names = {b["Name"] for b in response.get("Buckets", [])}
    backup_buckets = {"velero", "backups"}
    found = backup_buckets & bucket_names
    assert found, (
        f"No backup bucket found in MinIO. "
        f"Expected one of {backup_buckets}, got {bucket_names}"
    )
