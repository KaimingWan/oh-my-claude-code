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


# --- Task 4 + 5 tests: batch prompt + banner ---
from scripts.lib.plan import TaskInfo
from scripts.lib.scheduler import Batch


def _import_build_batch_prompt():
    """Import build_batch_prompt from ralph_loop without running module-level code."""
    import importlib.util
    spec = importlib.util.spec_from_file_location("ralph_loop", "scripts/ralph_loop.py",
                                                    submodule_search_locations=[])
    # We can't import the module directly (it runs main-loop code at import time).
    # Instead, read the source and extract the function.
    source = Path("scripts/ralph_loop.py").read_text()
    # Extract function via exec in isolated namespace
    ns = {"Path": Path, "Batch": Batch}
    # Find and exec just the function
    import re
    match = re.search(r'(def build_batch_prompt\(.*?\n(?=\ndef |\n# ))', source, re.DOTALL)
    if match:
        exec(match.group(1), ns)
        return ns["build_batch_prompt"]
    return None


def test_parallel_prompt_contains_dispatch():
    fn = _import_build_batch_prompt()
    assert fn is not None, "build_batch_prompt not found in ralph_loop.py"
    batch = Batch(tasks=[
        TaskInfo(1, "Parser", {"a.py"}, ""),
        TaskInfo(2, "Scheduler", {"b.py"}, ""),
    ], parallel=True)
    prompt = fn(batch, Path("docs/plans/test.md"), 1)
    assert "executor" in prompt.lower()
    assert "parallel" in prompt.lower()
    prompt_lower = prompt.lower()
    assert "use_subagent" in prompt_lower or "agent_name" in prompt_lower


def test_sequential_prompt_no_dispatch():
    fn = _import_build_batch_prompt()
    assert fn is not None, "build_batch_prompt not found in ralph_loop.py"
    batch = Batch(tasks=[
        TaskInfo(1, "Parser", {"a.py"}, ""),
    ], parallel=False)
    prompt = fn(batch, Path("docs/plans/test.md"), 1)
    assert "dispatch" not in prompt.lower()


def test_batch_mode_startup_banner(tmp_path):
    """Plan with 2 independent tasks → stdout contains 'batch'."""
    task_section = (
        "## Tasks\n\n"
        + "### " + "Task 1: Alpha\n\n**Files:**\n- Create: `a.py`\n\n**Verify:** `echo ok`\n\n---\n\n"
        + "### " + "Task 2: Beta\n\n**Files:**\n- Create: `b.py`\n\n**Verify:** `echo ok`\n\n"
    )
    plan_text = PLAN_TEMPLATE.format(items="- [ ] alpha | `echo ok`\n- [ ] beta | `echo ok`")
    # Insert task section before checklist
    plan_text = plan_text.replace("## Checklist", task_section + "## Checklist")
    write_plan(tmp_path, items="- [ ] alpha | `echo ok`\n- [ ] beta | `echo ok`")
    (tmp_path / "plan.md").write_text(plan_text)
    r = run_ralph(tmp_path)
    assert "batch" in r.stdout.lower()


def test_dependent_tasks_sequential_banner(tmp_path):
    """Plan with 2 tasks sharing a file → stdout contains 'sequential'."""
    task_section = (
        "## Tasks\n\n"
        + "### " + "Task 1: Alpha\n\n**Files:**\n- Modify: `shared.py`\n\n**Verify:** `echo ok`\n\n---\n\n"
        + "### " + "Task 2: Beta\n\n**Files:**\n- Modify: `shared.py`\n\n**Verify:** `echo ok`\n\n"
    )
    plan_text = PLAN_TEMPLATE.format(items="- [ ] alpha | `echo ok`\n- [ ] beta | `echo ok`")
    plan_text = plan_text.replace("## Checklist", task_section + "## Checklist")
    write_plan(tmp_path, items="- [ ] alpha | `echo ok`\n- [ ] beta | `echo ok`")
    (tmp_path / "plan.md").write_text(plan_text)
    r = run_ralph(tmp_path)
    assert "sequential" in r.stdout.lower()


def test_fallback_no_task_structure(tmp_path):
    """Plan with checklist but no task sections → runs without crash, exits normally."""
    write_plan(tmp_path, items="- [ ] simple task | `echo ok`")
    r = run_ralph(tmp_path, extra_env={"RALPH_KIRO_CMD": "true"}, max_iter="2")
    # Should not crash — either completes or hits circuit breaker
    assert r.returncode in (0, 1)
    # Should not contain traceback
    assert "Traceback" not in r.stdout
    assert "Traceback" not in r.stderr
