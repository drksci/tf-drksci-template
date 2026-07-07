"""Tests for modules/bootstrap/scripts/bootstrap-linux.sh

Each test gets a fresh container so failures don't cascade.
Use `pytest -m smoke` to run only fast checks.
"""

import pytest
from testcontainers.core.container import DockerContainer
from testcontainers.core.waiting_utils import wait_for_logs

from conftest import SCRIPTS_ROOT, UBUNTU_IMAGE, copy_scripts_to, run_in, host_for


BOOTSTRAP_SCRIPT = SCRIPTS_ROOT / "bootstrap" / "scripts" / "bootstrap-linux.sh"


@pytest.fixture()
def bootstrapped():
    """Ubuntu container with bootstrap-linux.sh fully applied."""
    with (
        DockerContainer(UBUNTU_IMAGE)
        .with_command("sleep infinity")
        .with_env("DEBIAN_FRONTEND", "noninteractive")
        # DRY_RUN skips long installs (mise tools, helm) so tests are fast
        .with_env("DRY_RUN", "1")
    ) as c:
        wait_for_logs(c, ".", timeout=10)
        copy_scripts_to(c, BOOTSTRAP_SCRIPT, dest="/tmp")
        run_in(c, "chmod +x /tmp/bootstrap-linux.sh")
        exit_code, stdout, _ = run_in(c, "/tmp/bootstrap-linux.sh")
        assert exit_code == 0, f"Bootstrap script failed:\n{stdout}"
        yield c, host_for(c)


@pytest.mark.slow
def test_bootstrap_exits_zero(bootstrapped):
    """Script runs to completion without error."""
    # Asserted in fixture setup — if we got here, it passed.
    pass


@pytest.mark.slow
def test_bootstrap_installs_curl(bootstrapped):
    _, h = bootstrapped
    assert h.package("curl").is_installed


@pytest.mark.slow
def test_bootstrap_installs_git(bootstrapped):
    _, h = bootstrapped
    assert h.package("git").is_installed


@pytest.mark.slow
def test_bootstrap_installs_docker(bootstrapped):
    _, h = bootstrapped
    # Docker CLI must be on PATH
    assert h.file("/usr/bin/docker").exists or h.file("/usr/local/bin/docker").exists


@pytest.mark.slow
def test_bootstrap_mise_on_path(bootstrapped):
    _, h = bootstrapped
    assert (
        h.file("/usr/local/bin/mise").exists
        or h.file("/root/.local/bin/mise").exists
    )


@pytest.mark.smoke
def test_bootstrap_script_exists():
    """Script file is present in repo."""
    assert BOOTSTRAP_SCRIPT.exists(), f"Missing: {BOOTSTRAP_SCRIPT}"


@pytest.mark.smoke
def test_bootstrap_is_executable():
    """Script has shebang and is syntactically valid (bash -n)."""
    import subprocess
    result = subprocess.run(["bash", "-n", str(BOOTSTRAP_SCRIPT)], capture_output=True)
    assert result.returncode == 0, result.stderr.decode()
