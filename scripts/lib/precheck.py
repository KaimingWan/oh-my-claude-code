"""Environment pre-check — detect and run project test suite."""
import os
import signal
import subprocess
from pathlib import Path


def detect_test_command(project_root: Path) -> str:
    if (
        (project_root / "pyproject.toml").exists()
        or (project_root / "pytest.ini").exists()
        or (project_root / "setup.cfg").exists()
        or (project_root / "conftest.py").exists()
        or (project_root / "tests").is_dir()
    ):
        return "python3 -m pytest -x -q -m 'not slow' --ignore=tests/ralph-loop"
    if (project_root / "package.json").exists():
        return "npm test --silent"
    if (project_root / "Cargo.toml").exists():
        return "cargo test 2>&1"
    if (project_root / "go.mod").exists():
        return "go test ./... 2>&1"
    return ""


def run_precheck(project_root: Path, timeout: int = 60) -> tuple[bool, str]:
    cmd = detect_test_command(project_root)
    if not cmd:
        return True, "No test command detected"
    try:
        proc = subprocess.Popen(
            cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            text=True, cwd=project_root, start_new_session=True,
        )
        try:
            stdout, stderr = proc.communicate(timeout=timeout)
            lines = (stdout + stderr).strip().split('\n')
            return proc.returncode == 0, '\n'.join(lines[-20:])
        except subprocess.TimeoutExpired:
            os.killpg(os.getpgid(proc.pid), signal.SIGKILL)
            proc.wait()
            return False, f"Test timed out after {timeout}s"
    except Exception as e:
        return False, f"Precheck error: {e}"
