"""Shared fixtures for homelab script tests."""

import os
import subprocess
from pathlib import Path

import pytest
import testinfra
from testcontainers.core.container import DockerContainer
from testcontainers.core.waiting_utils import wait_for_logs

SCRIPTS_ROOT = Path(__file__).parents[2] / "modules"
REPO_ROOT = Path(__file__).parents[2]

UBUNTU_IMAGE = "ubuntu:22.04"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def copy_scripts_to(container, *src_paths: Path, dest: str = "/scripts"):
    """Copy one or more files into a running container."""
    container.exec("mkdir -p " + dest)
    for src in src_paths:
        container.copy_to_machine(str(src), dest + "/" + src.name)


def run_in(container, cmd: str, env: dict | None = None) -> tuple[int, str, str]:
    """Run a shell command inside the container, return (exit_code, stdout, stderr)."""
    env_prefix = " ".join(f'{k}="{v}"' for k, v in (env or {}).items())
    full = f"{env_prefix} {cmd}".strip()
    result = container.exec(["bash", "-c", full])
    return result.exit_code, result.output.decode(), ""


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture(scope="session")
def ubuntu_container():
    """Bare Ubuntu 22.04 container — used for bootstrap tests."""
    with (
        DockerContainer(UBUNTU_IMAGE)
        .with_command("sleep infinity")
        .with_env("DEBIAN_FRONTEND", "noninteractive")
    ) as c:
        # Wait for container to be usable
        wait_for_logs(c, ".", timeout=10)
        yield c


@pytest.fixture(scope="session")
def ubuntu_with_mise(ubuntu_container):
    """Ubuntu container with mise pre-installed (reused across tests in session)."""
    c = ubuntu_container
    # Install curl + git (mise prerequisite)
    run_in(c, "apt-get update -qq && apt-get install -y -qq curl git")
    # Install mise
    run_in(c, 'curl -fsSL https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise sh')
    return c


@pytest.fixture()
def host(ubuntu_container):
    """testinfra host object for the ubuntu container — use for assertions."""
    return testinfra.get_host(
        "docker://" + ubuntu_container.get_wrapped_container().id
    )


# ---------------------------------------------------------------------------
# Utility: testinfra host scoped to a specific container
# ---------------------------------------------------------------------------

def host_for(container):
    return testinfra.get_host(
        "docker://" + container.get_wrapped_container().id
    )
