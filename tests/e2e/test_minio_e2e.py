"""
Extended MinIO end-to-end tests.

These tests validate in-cluster S3 access via the headless Service/Endpoints
bridge, multipart uploads, and bucket ACL enforcement.

All tests require a live cluster (``@pytest.mark.e2e``).
"""

from __future__ import annotations

import io
import os
import uuid

import pytest
import requests
from kubernetes import client as k8s_client
from tenacity import retry, stop_after_delay, wait_fixed

pytestmark = pytest.mark.e2e

_PART_SIZE = 5 * 1024 * 1024  # 5 MiB — minimum part size for S3 multipart


# ---------------------------------------------------------------------------
# In-cluster S3 access via aws-cli pod (slow)
# ---------------------------------------------------------------------------


@pytest.mark.slow
def test_in_cluster_s3_access(k8s_core: k8s_client.CoreV1Api) -> None:
    """
    Prove that in-cluster pods can reach MinIO via the headless Service +
    Endpoints bridge (minio.minio.svc.cluster.local:9000).

    Spawns an ``amazon/aws-cli`` pod, runs ``aws s3 ls``, and asserts exit 0.
    """
    access_key = os.environ.get("MINIO_ROOT_USER", "admin")
    secret_key = os.environ.get("MINIO_ROOT_PASSWORD", "")

    if not secret_key:
        pytest.skip("MINIO_ROOT_PASSWORD not set — skipping in-cluster S3 test")

    pod_name = f"e2e-s3-{uuid.uuid4().hex[:8]}"
    namespace = "default"
    endpoint = "http://minio.minio.svc.cluster.local:9000"

    pod_body = k8s_client.V1Pod(
        metadata=k8s_client.V1ObjectMeta(
            name=pod_name,
            labels={"created-by": "homelab-e2e"},
        ),
        spec=k8s_client.V1PodSpec(
            restart_policy="Never",
            containers=[
                k8s_client.V1Container(
                    name="aws-cli",
                    image="amazon/aws-cli:latest",
                    command=[
                        "aws",
                        "s3",
                        "ls",
                        f"--endpoint-url={endpoint}",
                        "--no-verify-ssl",
                    ],
                    env=[
                        k8s_client.V1EnvVar(
                            name="AWS_ACCESS_KEY_ID",
                            value=access_key,
                        ),
                        k8s_client.V1EnvVar(
                            name="AWS_SECRET_ACCESS_KEY",
                            value=secret_key,
                        ),
                        k8s_client.V1EnvVar(
                            name="AWS_DEFAULT_REGION",
                            value="us-east-1",
                        ),
                    ],
                )
            ],
        ),
    )

    k8s_core.create_namespaced_pod(namespace, pod_body)

    try:
        @retry(stop=stop_after_delay(120), wait=wait_fixed(5))
        def _wait_done() -> None:
            pod = k8s_core.read_namespaced_pod(pod_name, namespace)
            if pod.status.phase not in ("Succeeded", "Failed"):
                raise RuntimeError(f"Pod {pod_name} still running: {pod.status.phase}")

        _wait_done()

        pod = k8s_core.read_namespaced_pod(pod_name, namespace)
        logs = k8s_core.read_namespaced_pod_log(pod_name, namespace)

        assert pod.status.phase == "Succeeded", (
            f"In-cluster S3 access pod failed (phase={pod.status.phase}).\n"
            f"Logs:\n{logs}"
        )

    finally:
        try:
            k8s_core.delete_namespaced_pod(pod_name, namespace)
        except Exception:
            pass


# ---------------------------------------------------------------------------
# Multipart upload
# ---------------------------------------------------------------------------


def test_multipart_upload(minio_s3) -> None:
    """
    Upload a 10 MiB object using S3 multipart in 5 MiB parts,
    verify the ETag is present, then delete the object.
    """
    bucket = f"e2e-multipart-{uuid.uuid4().hex[:10]}"
    key = "multipart/10mb-object.bin"
    total_size = 10 * 1024 * 1024  # 10 MiB

    minio_s3.create_bucket(Bucket=bucket)

    try:
        mpu = minio_s3.create_multipart_upload(Bucket=bucket, Key=key)
        upload_id = mpu["UploadId"]

        parts = []
        data = b"\xab" * total_size
        part_number = 1
        offset = 0

        while offset < total_size:
            chunk = data[offset : offset + _PART_SIZE]
            resp = minio_s3.upload_part(
                Bucket=bucket,
                Key=key,
                UploadId=upload_id,
                PartNumber=part_number,
                Body=chunk,
            )
            parts.append({"PartNumber": part_number, "ETag": resp["ETag"]})
            part_number += 1
            offset += _PART_SIZE

        complete = minio_s3.complete_multipart_upload(
            Bucket=bucket,
            Key=key,
            UploadId=upload_id,
            MultipartUpload={"Parts": parts},
        )

        assert complete.get("ETag"), (
            "Completed multipart upload did not return an ETag"
        )

        # Verify object is retrievable
        head = minio_s3.head_object(Bucket=bucket, Key=key)
        assert head["ContentLength"] == total_size, (
            f"Uploaded {total_size} bytes but object reports {head['ContentLength']}"
        )

    finally:
        try:
            minio_s3.delete_object(Bucket=bucket, Key=key)
        except Exception:
            pass
        try:
            minio_s3.delete_bucket(Bucket=bucket)
        except Exception:
            pass


# ---------------------------------------------------------------------------
# Bucket policy — unauthenticated access denied
# ---------------------------------------------------------------------------


def test_bucket_policy_private(minio_s3, internal_domain: str) -> None:
    """
    Create a bucket (default policy is private) and verify that an
    unauthenticated HEAD request returns 403.
    """
    bucket = f"e2e-private-{uuid.uuid4().hex[:10]}"
    key = "private-object.txt"

    minio_s3.create_bucket(Bucket=bucket)

    try:
        minio_s3.put_object(Bucket=bucket, Key=key, Body=b"private content")

        # Build a direct URL to the object — routed via Traefik s3 host header
        # We use the boto3 endpoint_url to get the base URL
        endpoint_url = minio_s3.meta.endpoint_url.rstrip("/")
        object_url = f"{endpoint_url}/{bucket}/{key}"

        # Unauthenticated GET — no auth headers
        resp = requests.get(object_url, timeout=10)
        assert resp.status_code in (400, 403), (
            f"Expected 400 or 403 for private bucket object, got {resp.status_code}. "
            "Bucket may be inadvertently public."
        )

    finally:
        try:
            minio_s3.delete_object(Bucket=bucket, Key=key)
        except Exception:
            pass
        try:
            minio_s3.delete_bucket(Bucket=bucket)
        except Exception:
            pass
