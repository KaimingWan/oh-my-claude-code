# Ralph Loop Fork Bomb & Orphan Process Fix

**Goal:** Eliminate the recursive fork bomb caused by `run_precheck()` → pytest → ralph tests → ralph_loop.py → `run_precheck()` → ∞, and fix orphan child processes surviving after ralph_loop.py is killed.

**Non-Goals:** Not changing the precheck feature's purpose (it still runs tests). Not changing ralph_loop.py's iteration/timeout/circuit-breaker logic. Not changing test structure or test coverage scope.

**Architecture:** Three-layer fix: (1) `run_precheck()` excludes `tests/ralph-loop/` from its pytest invocation — this is the root cause fix since precheck's purpose is environment health, not integration testing. (2) `ralph_loop.py` sets `_RALPH_LOOP_RUNNING=1` env var on startup and dies if already set — safety net against any future recursion vector. (3) Keep `start_new_session=True` (needed for timeout killpg) but add explicit child PID tracking in `_cleanup_handler`, so killing ralph also kills its child CLI process's process group instead of orphaning it.

**Tech Stack:** Python 3, pytest

## Review

Round 1 (4 reviewers parallel):
- Goal Alignment: APPROVE — all tasks map to goal, execution order valid, non-goals correct
- Verify Correctness: APPROVE — 8/8 verify commands sound
- Completeness: REJECT → fixed below
- Technical Feasibility: REJECT → fixed below

Post-review fixes applied:
1. Architecture description: "Replace start_new_session" → "Keep + add child tracking" (was contradicting implementation)
2. Task 1: merge --ignore with existing `-m 'not slow'` flag from context-optimization plan
3. Task 1 test: use tmp_path instead of Path(".") to avoid cwd dependency
4. Task 3 _cleanup_handler: remove poll() check, directly try killpg (async-signal-safe)
5. Task 3 test: replace sleep(2) with poll loop for robustness

## Tasks

### Task 1: Precheck Excludes Ralph Tests (Root Cause)

**Files:**
- Modify: `scripts/lib/precheck.py`
- Test: `tests/ralph-loop/test_precheck.py`

**Verify:** `python3 -m pytest tests/ralph-loop/test_precheck.py -v`

**Step 1: Write failing test**

In `tests/ralph-loop/test_precheck.py`, add:
```python
def test_precheck_excludes_ralph_tests(tmp_path):
    """Precheck pytest command must exclude tests/ralph-loop/ to prevent recursion."""
    (tmp_path / "pyproject.toml").write_text("[tool.pytest]\n")
    from scripts.lib.precheck import detect_test_command
    cmd = detect_test_command(tmp_path)
    assert "pytest" in cmd
    assert "--ignore=tests/ralph-loop" in cmd
```

**Step 2: Run test — verify it fails**
Run: `python3 -m pytest tests/ralph-loop/test_precheck.py::test_precheck_excludes_ralph_tests -v`
Expected: FAIL (current command has no --ignore)

**Step 3: Implement**

In `scripts/lib/precheck.py`, change the pytest command:
```python
return "python3 -m pytest -x -q -m 'not slow' --ignore=tests/ralph-loop"
```

**Step 4: Run test — verify it passes**

**Step 5: Commit**

---

### Task 2: Ralph Loop Recursion Guard (Safety Net)

**Files:**
- Modify: `scripts/ralph_loop.py`
- Test: `tests/ralph-loop/test_ralph_loop.py`

**Verify:** `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_recursion_guard -v`

**Step 1: Write failing test**

In `tests/ralph-loop/test_ralph_loop.py`, add:
```python
def test_recursion_guard(tmp_path):
    """ralph_loop.py exits immediately if _RALPH_LOOP_RUNNING is set."""
    write_plan(tmp_path)
    r = run_ralph(tmp_path, extra_env={
        "RALPH_KIRO_CMD": "true",
        "_RALPH_LOOP_RUNNING": "1",
    })
    assert r.returncode == 1
    assert "nested" in r.stdout.lower() or "recursion" in r.stdout.lower()
```

**Step 2: Run test — verify it fails**
Run: `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_recursion_guard -v`
Expected: FAIL

**Step 3: Implement**

In `scripts/ralph_loop.py`, add after the imports/config section (before `PLAN_POINTER` resolution):
```python
if os.environ.get("_RALPH_LOOP_RUNNING"):
    die("Nested ralph loop detected — aborting to prevent recursion")
os.environ["_RALPH_LOOP_RUNNING"] = "1"
```

**Step 4: Run test — verify it passes**

**Step 5: Commit**

---

### Task 3: Fix Orphan Child Processes

**Files:**
- Modify: `scripts/ralph_loop.py`
- Test: `tests/ralph-loop/test_ralph_loop.py`

**Verify:** `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_no_orphan_after_ralph_killed -v`

**Step 1: Write failing test**

In `tests/ralph-loop/test_ralph_loop.py`, add:
```python
def test_no_orphan_after_ralph_killed(tmp_path):
    """Killing ralph_loop.py also kills its child CLI process (no orphans)."""
    write_plan(tmp_path)
    unique_name = f"ralph_orphan_test_{os.getpid()}"
    script = tmp_path / f"{unique_name}.sh"
    script.write_text(f"#!/bin/bash\nexec -a {unique_name} sleep 120\n")
    script.chmod(0o755)

    proc = subprocess.Popen(
        ["python3", SCRIPT, "1"],
        env={
            "PATH": os.environ.get("PATH", "/usr/bin:/bin"),
            "HOME": os.environ.get("HOME", "/tmp"),
            "PLAN_POINTER_OVERRIDE": str(tmp_path / ".active"),
            "RALPH_KIRO_CMD": str(script),
            "RALPH_TASK_TIMEOUT": "60",
            "RALPH_HEARTBEAT_INTERVAL": "999",
            "RALPH_SKIP_DIRTY_CHECK": "1",
        },
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    # Wait for child to start (poll loop instead of sleep)
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        check = subprocess.run(["pgrep", "-f", unique_name], capture_output=True, text=True)
        if check.returncode == 0:
            break
        time.sleep(0.2)
    # Kill ralph (SIGTERM)
    proc.terminate()
    proc.wait(timeout=5)
    time.sleep(1)
    # Child should NOT be orphaned
    check = subprocess.run(["pgrep", "-f", unique_name], capture_output=True, text=True)
    assert check.returncode != 0, f"Orphan child found: {check.stdout.strip()}"
```

**Step 2: Run test — verify it fails**
Run: `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_no_orphan_after_ralph_killed -v`
Expected: FAIL (current code uses start_new_session=True, child survives)

**Step 3: Implement**

In `scripts/ralph_loop.py`:

1. Add a module-level variable to track the child process:
```python
_child_proc: subprocess.Popen | None = None
```

2. Update `_cleanup_handler` to kill the child:
```python
def _cleanup_handler(signum=None, frame=None):
    if _child_proc is not None:
        try:
            os.killpg(os.getpgid(_child_proc.pid), signal.SIGTERM)
        except (ProcessLookupError, OSError):
            pass
    LOCK.release()
    sys.exit(1)
```

3. In the main loop, keep `start_new_session=True` (needed for `killpg` on timeout) but track the child:
```python
        proc = subprocess.Popen(
            cmd, stdout=log_fd, stderr=subprocess.STDOUT,
            start_new_session=True,
        )
        _child_proc = proc
```

**Step 4: Run test — verify it passes**

**Step 5: Commit**

---

## Checklist

- [x] precheck pytest 命令包含 --ignore=tests/ralph-loop | `python3 -c "from scripts.lib.precheck import detect_test_command; from pathlib import Path; cmd = detect_test_command(Path('.')); assert '--ignore=tests/ralph-loop' in cmd, cmd"`
- [x] 递归守卫阻止嵌套 ralph | `_RALPH_LOOP_RUNNING=1 python3 scripts/ralph_loop.py 2>&1; test $? -eq 1`
- [x] 杀 ralph 后子进程不残留 | `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_no_orphan_after_ralph_killed -v`
- [x] 回归测试通过 | `python3 -m pytest tests/ralph-loop/ -m 'not slow' -q`

## Errors

| Error | Task | Attempt | Resolution |
|-------|------|---------|------------|
