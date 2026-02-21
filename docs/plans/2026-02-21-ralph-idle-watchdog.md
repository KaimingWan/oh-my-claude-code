# Ralph Loop Idle Watchdog Implementation Plan

**Goal:** Add PTY-based unbuffered output and idle watchdog to ralph_loop.py so stuck iterations are killed within 60s instead of waiting the full task_timeout (default 1800s).
**Non-Goals:** Parallel execution, prompt optimization, adaptive timeout, changing circuit breaker logic.
**Architecture:** Wrap child CLI process in a PTY (via `pty.openpty()`) so output is line-buffered. A reader thread tees PTY output to the log file. The existing heartbeat thread monitors log file mtime; if no growth for `idle_timeout` seconds, it kills the child process group.
**Tech Stack:** Python 3 stdlib (`pty`, `os`, `threading`, `subprocess`)

## Tasks

### Task 1: PTY subprocess launcher

**Files:**
- Create: `scripts/lib/pty_runner.py`
- Test: `tests/ralph-loop/test_pty_runner.py`

**Step 1: Write failing test**

```python
# tests/ralph-loop/test_pty_runner.py
import time, os, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from scripts.lib.pty_runner import pty_run

def test_output_is_unbuffered(tmp_path):
    """PTY runner captures output line-by-line without waiting for process exit."""
    log = tmp_path / "out.log"
    # Python script that prints two lines with a sleep between them
    script = 'import time; print("line1"); time.sleep(1); print("line2")'
    proc, stop = pty_run(["python3", "-c", script], log)
    time.sleep(0.5)
    # line1 should already be in the log (unbuffered)
    assert "line1" in log.read_text()
    proc.wait()
    stop()
    assert "line2" in log.read_text()

def test_returncode_preserved(tmp_path):
    """Exit code from child process is preserved."""
    log = tmp_path / "out.log"
    proc, stop = pty_run(["python3", "-c", "import sys; sys.exit(42)"], log)
    proc.wait()
    stop()
    assert proc.returncode == 42

def test_process_group_isolation(tmp_path):
    """Child runs in its own process group (start_new_session=True)."""
    log = tmp_path / "out.log"
    proc, stop = pty_run(["python3", "-c", "import os; print(os.getpgid(0))"], log)
    proc.wait()
    stop()
    child_pgid = int(log.read_text().strip().split('\n')[0].strip())
    assert child_pgid != os.getpgid(0)
```

**Step 2: Run test — verify it fails**
Run: `python3 -m pytest tests/ralph-loop/test_pty_runner.py -v`
Expected: FAIL (module not found)

**Step 3: Write minimal implementation**

```python
# scripts/lib/pty_runner.py
"""PTY-based subprocess runner for unbuffered output capture."""
import os
import pty
import subprocess
import threading
from pathlib import Path


def pty_run(cmd: list[str], log_path: Path) -> tuple[subprocess.Popen, callable]:
    """Launch cmd with stdout/stderr on a PTY, tee output to log_path.

    Returns (proc, stop_fn). Call stop_fn() after proc.wait() to join reader thread.
    """
    master, slave = pty.openpty()
    proc = subprocess.Popen(
        cmd, stdout=slave, stderr=subprocess.STDOUT,
        start_new_session=True, close_fds=True,
    )
    os.close(slave)

    stop_event = threading.Event()

    def _reader():
        with open(log_path, "ab") as f:
            while not stop_event.is_set():
                try:
                    data = os.read(master, 4096)
                    if not data:
                        break
                    f.write(data)
                    f.flush()
                except OSError:
                    break
        try:
            os.close(master)
        except OSError:
            pass

    t = threading.Thread(target=_reader, daemon=True)
    t.start()

    def stop():
        stop_event.set()
        try:
            os.close(master)
        except OSError:
            pass
        t.join(timeout=2)

    return proc, stop
```

**Step 4: Run test — verify it passes**
Run: `python3 -m pytest tests/ralph-loop/test_pty_runner.py -v`
Expected: PASS

**Step 5: Commit**
`feat: add PTY subprocess runner for unbuffered output`

---

### Task 2: Idle watchdog in heartbeat thread

**Files:**
- Modify: `scripts/ralph_loop.py`
- Test: `tests/ralph-loop/test_ralph_loop.py`

**Step 1: Write failing test**

Add to `tests/ralph-loop/test_ralph_loop.py`:

```python
def test_idle_watchdog_kills_silent_process(tmp_path):
    """Process that produces no output is killed by idle watchdog before task_timeout."""
    write_plan(tmp_path)
    # silent_script produces zero output, just sleeps
    script = tmp_path / "silent.sh"
    script.write_text("#!/bin/bash\nsleep 300\n")
    script.chmod(0o755)
    import time
    start = time.monotonic()
    r = run_ralph(tmp_path, extra_env={
        "RALPH_KIRO_CMD": str(script),
        "RALPH_TASK_TIMEOUT": "300",
        "RALPH_IDLE_TIMEOUT": "3",
    }, max_iter="1")
    elapsed = time.monotonic() - start
    assert r.returncode == 1
    # Should be killed by idle watchdog (~3s), not task_timeout (300s)
    assert elapsed < 30, f"Took {elapsed:.0f}s — idle watchdog didn't fire"
```

**Step 2: Run test — verify it fails**
Run: `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_idle_watchdog_kills_silent_process -v`
Expected: FAIL (no RALPH_IDLE_TIMEOUT support yet)

**Step 3: Write minimal implementation**

Changes to `scripts/ralph_loop.py`:

1. Add `idle_timeout` to `Config`:
```python
@dataclass
class Config:
    max_iterations: int = 10
    task_timeout: int = 1800
    idle_timeout: int = 60
    heartbeat_interval: int = 60
    # ... rest unchanged
```

2. Parse from env in `parse_config`:
```python
idle_timeout=int(os.environ.get("RALPH_IDLE_TIMEOUT", "60")),
```

3. Replace the `with log_file.open("a") as log_fd:` block (lines 329-365) with:
   - Call `proc, pty_stop = pty_run(cmd, log_file)` (import from scripts.lib.pty_runner)
   - Remove the old `subprocess.Popen(cmd, stdout=log_fd, ...)` call
   - After `proc.wait()` / timeout handling, call `pty_stop()` to join the reader thread
   - Update `child_proc_ref[0] = proc` to use the proc from pty_run

4. Update the `_heartbeat` call site (around line 280) to pass the new parameters:
   `args=(proc, i, stop_event, plan, heartbeat_interval, log_file, idle_timeout)`

5. Modify `_heartbeat` to check log file size:
```python
def _heartbeat(proc, iteration, stop_event, plan, heartbeat_interval,
               log_path, idle_timeout):
    last_size = log_path.stat().st_size if log_path.exists() else 0
    idle_elapsed = 0
    while not stop_event.wait(heartbeat_interval):
        if proc.poll() is not None:
            break
        plan.reload()
        cur_size = log_path.stat().st_size if log_path.exists() else 0
        if cur_size > last_size:
            last_size = cur_size
            idle_elapsed = 0
        else:
            idle_elapsed += heartbeat_interval
        if idle_timeout > 0 and idle_elapsed >= idle_timeout:
            ts = datetime.now().strftime("%H:%M:%S")
            print(f"🧊 [{ts}] Iteration {iteration} — no output for {idle_elapsed}s, killing (idle watchdog)",
                  flush=True)
            try:
                os.killpg(os.getpgid(proc.pid), signal.SIGTERM)
            except (ProcessLookupError, OSError):
                pass
            break
        ts = datetime.now().strftime("%H:%M:%S")
        print(f"💓 [{ts}] Iteration {iteration} — {plan.checked}/{plan.total} done (idle {idle_elapsed}s)",
              flush=True)
```

6. Wire `idle_timeout = cfg.idle_timeout` in main() alongside other config reads.

**Step 4: Run test — verify it passes**
Run: `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_idle_watchdog_kills_silent_process -v`
Expected: PASS

**Step 5: Commit**
`feat: add idle watchdog — kill stuck iterations within 60s`

---

### Task 3: Integration and regression

**Files:**
- Modify: `scripts/ralph_loop.py`
- Test: `tests/ralph-loop/test_ralph_loop.py`

**Step 1: Write failing test**

```python
def test_active_process_not_killed_by_idle_watchdog(tmp_path):
    """Process that produces output every second survives past idle_timeout."""
    write_plan(tmp_path)
    script = tmp_path / "chatty.sh"
    script.write_text("#!/bin/bash\nfor i in $(seq 1 10); do echo tick$i; sleep 1; done\n")
    script.chmod(0o755)
    import time
    start = time.monotonic()
    r = run_ralph(tmp_path, extra_env={
        "RALPH_KIRO_CMD": str(script),
        "RALPH_TASK_TIMEOUT": "30",
        "RALPH_IDLE_TIMEOUT": "3",
        "RALPH_HEARTBEAT_INTERVAL": "1",
    }, max_iter="1")
    elapsed = time.monotonic() - start
    # Script runs ~10s, should NOT be killed by 3s idle watchdog because it outputs every 1s
    assert elapsed >= 8, f"Killed too early at {elapsed:.0f}s — false positive"
```

**Step 2: Run test — verify it fails**
Run: `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_active_process_not_killed_by_idle_watchdog -v`
Expected: FAIL or PASS (depends on Task 2 implementation correctness)

**Step 3: Fix any issues, then run full regression**
Run: `python3 -m pytest tests/ralph-loop/ -v`
Expected: ALL PASS

**Step 4: Commit**
`test: idle watchdog false-positive guard + regression`

## Review
<!-- Reviewer writes here -->

## Checklist

- [ ] PTY runner 输出无缓冲 | `python3 -m pytest tests/ralph-loop/test_pty_runner.py -v`
- [ ] idle watchdog 杀死静默进程 | `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_idle_watchdog_kills_silent_process -v`
- [ ] 活跃进程不被误杀 | `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_active_process_not_killed_by_idle_watchdog -v`
- [ ] 回归测试通过 | `python3 -m pytest tests/ralph-loop/ -v`

## Errors

| Error | Task | Attempt | Resolution |
|-------|------|---------|------------|
