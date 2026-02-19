import os
import subprocess
import pytest

_PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

@pytest.fixture(autouse=True)
def _guard_cwd_and_head():
    """Fail-safe: restore cwd and git HEAD after every test."""
    original_cwd = os.getcwd()
    head_before = subprocess.run(
        ["git", "rev-parse", "HEAD"], capture_output=True, text=True,
        cwd=_PROJECT_ROOT
    ).stdout.strip()
    yield
    os.chdir(original_cwd)
    head_after = subprocess.run(
        ["git", "rev-parse", "HEAD"], capture_output=True, text=True,
        cwd=_PROJECT_ROOT
    ).stdout.strip()
    if head_after != head_before:
        subprocess.run(["git", "reset", "--hard", head_before],
                       capture_output=True, cwd=_PROJECT_ROOT)
        for line in subprocess.run(
            ["git", "branch", "--list", "ralph-worker-*"],
            capture_output=True, text=True, cwd=_PROJECT_ROOT
        ).stdout.splitlines():
            b = line.strip()
            if b:
                subprocess.run(["git", "branch", "-D", b],
                               capture_output=True, cwd=_PROJECT_ROOT)
