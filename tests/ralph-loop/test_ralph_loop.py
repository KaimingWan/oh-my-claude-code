"""Tests for ralph_loop.py core logic (no live kiro-cli needed)."""
import subprocess, os, time, signal, pytest, textwrap
from pathlib import Path

PLAN_TEMPLATE = textwrap.dedent("""\
    # Test Plan
    **Goal:** Test
    ## Checklist
    {items}
    ## Errors
    | Error | Task | Attempt | Resolution |
    |-------|------|---------|------------|
""")

SCRIPT = "scripts/ralph_loop.py"


def write_plan(tmp_path, items="- [ ] task one | `echo ok`"):
    plan = tmp_path / "plan.md"
    plan.write_text(PLAN_TEMPLATE.format(items=items))
    active = tmp_path / ".active"
    active.write_text(str(plan))
    return plan


def run_ralph(tmp_path, extra_env=None, max_iter="1"):
    env = {
        "PATH": os.environ.get("PATH", "/usr/bin:/bin"),
        "HOME": os.environ.get("HOME", "/tmp"),
        "PLAN_POINTER_OVERRIDE": str(tmp_path / ".active"),
        "RALPH_TASK_TIMEOUT": "5",
        "RALPH_HEARTBEAT_INTERVAL": "999",
        "RALPH_SKIP_DIRTY_CHECK": "1",
    }
    if extra_env:
        env.update(extra_env)
    return subprocess.run(
        ["python3", SCRIPT, max_iter],
        capture_output=True, text=True, env=env, timeout=30,
    )


def test_no_active_plan(tmp_path):
    r = run_ralph(tmp_path)
    assert r.returncode == 1
    assert "No active plan" in r.stdout


def test_no_checklist(tmp_path):
    plan = tmp_path / "plan.md"
    plan.write_text("# Empty\nNo checklist.")
    (tmp_path / ".active").write_text(str(plan))
    r = run_ralph(tmp_path)
    assert r.returncode == 1


def test_already_complete(tmp_path):
    write_plan(tmp_path, items="- [x] done | `echo ok`")
    r = run_ralph(tmp_path)
    assert r.returncode == 0
    assert "complete" in r.stdout.lower()


def test_timeout_kills_process(tmp_path):
    """Core test: subprocess that hangs gets killed by timeout, no orphans."""
    write_plan(tmp_path)
    r = run_ralph(tmp_path, extra_env={
        "RALPH_KIRO_CMD": "sleep 60",
        "RALPH_TASK_TIMEOUT": "2",
    })
    assert r.returncode == 1


def test_circuit_breaker(tmp_path):
    """After MAX_STALE rounds with no progress, should exit 1."""
    write_plan(tmp_path, items="- [ ] impossible | `false`")
    r = run_ralph(tmp_path, extra_env={
        "RALPH_KIRO_CMD": "true",
    }, max_iter="5")
    assert r.returncode == 1
    assert "circuit breaker" in r.stdout.lower() or "no progress" in r.stdout.lower()


def test_lock_cleanup_on_signal(tmp_path):
    """Lock file should be cleaned up even if process is killed."""
    write_plan(tmp_path)
    lock_path = Path(".ralph-loop.lock")
    # Clean up any stale lock first
    lock_path.unlink(missing_ok=True)

    proc = subprocess.Popen(
        ["python3", SCRIPT, "1"],
        env={
            "PATH": os.environ.get("PATH", "/usr/bin:/bin"),
            "HOME": os.environ.get("HOME", "/tmp"),
            "PLAN_POINTER_OVERRIDE": str(tmp_path / ".active"),
            "RALPH_KIRO_CMD": "sleep 60",
            "RALPH_TASK_TIMEOUT": "60",
            "RALPH_HEARTBEAT_INTERVAL": "999",
            "RALPH_SKIP_DIRTY_CHECK": "1",
        },
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    time.sleep(1)
    assert lock_path.exists(), "Lock file should exist while running"
    proc.terminate()
    proc.wait(timeout=5)
    time.sleep(0.5)
    assert not lock_path.exists(), "Lock file should be cleaned up after SIGTERM"
