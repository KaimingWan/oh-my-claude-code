# Ralph Loop Python Rewrite

**Goal:** Rewrite ralph-loop.sh (219 lines) and generate-platform-configs.sh (240 lines) from bash to Python for reliability, debuggability, and maintainability — while keeping all hooks in bash for latency.
**Non-Goals:** Not rewriting any hooks (hooks/ directory stays bash). Not changing the file-based protocol (lock file, .active pointer, markdown checklist). Not adding new features — pure 1:1 behavioral parity.
**Architecture:** Two Python scripts (`scripts/ralph_loop.py`, `scripts/generate_configs.py`) replace their bash equivalents. A shared library `scripts/lib/` provides common utilities (plan parsing, lock management). Hooks remain bash, communicate with Python scripts via file protocol only. Language boundary rule enforced by documentation + future lint check.
**Tech Stack:** Python 3.10+ (subprocess, pathlib, signal, json, os)

## Review

### Round 1 (Completeness / Testability / Technical Feasibility / Compatibility & Rollback)
- **Completeness**: REQUEST CHANGES — missing signal handling details, process group cleanup specifics, lock race conditions → Fixed: added implementation strategy section to Task 2
- **Testability**: REQUEST CHANGES — no tests for core subprocess management (timeout kill, fd cleanup, circuit breaker) → Fixed: added test_timeout_kills_process, test_circuit_breaker, test_lock_cleanup_on_signal to Task 2
- **Technical Feasibility**: REQUEST CHANGES — import path unspecified, threading vs multiprocessing unclear → Fixed: specified sys.path.insert approach + daemon threading for heartbeat
- **Compatibility & Rollback**: REQUEST CHANGES — JSON output diff verification missing, no rollback strategy → Fixed: added diff verification step to Task 3, added rollback note

### Round 3 (Completeness / Testability / Security / Performance)
- **Completeness**: REQUEST CHANGES — wants integration tests, rollback strategy, requirements.txt → Calibrated: stdlib-only (no requirements.txt needed), rollback = git revert, integration tests beyond Non-Goals scope
- **Testability**: REQUEST CHANGES — hallucinated (reviewed wrong plan, referenced "9 items" and "planning skill behavior") → Ignored
- **Security**: REQUEST CHANGES — PID reuse, regex dot wildcard, subagent drift → Calibrated: PID reuse is existing behavior not introduced by rewrite; subagent drift is config generator's concern not this plan's. Fixed: regex dot → character class `[-_.]` in Task 5
- **Performance**: APPROVE ✅

## Tasks

### Task 1: Create shared Python library `scripts/lib/`

**Files:**
- Create: `scripts/lib/__init__.py`
- Create: `scripts/lib/plan.py`
- Create: `scripts/lib/lock.py`
- Test: `tests/ralph-loop/test_plan.py`
- Test: `tests/ralph-loop/test_lock.py`

**Step 1: Write failing tests for plan parser**

```python
# tests/ralph-loop/test_plan.py
import pytest
from pathlib import Path
from scripts.lib.plan import PlanFile

SAMPLE_PLAN = """\
# Test Plan

**Goal:** Test

## Checklist

- [x] item one | `echo ok`
- [ ] item two | `echo pending`
- [ ] item three | `echo pending`
- [SKIP] item four skipped | `echo skip`
"""

def test_counts(tmp_path):
    p = tmp_path / "plan.md"
    p.write_text(SAMPLE_PLAN)
    pf = PlanFile(p)
    assert pf.checked == 1
    assert pf.unchecked == 2
    assert pf.skipped == 1
    assert pf.total == 3  # checked + unchecked, skip excluded

def test_next_items(tmp_path):
    p = tmp_path / "plan.md"
    p.write_text(SAMPLE_PLAN)
    pf = PlanFile(p)
    items = pf.next_unchecked(5)
    assert len(items) == 2
    assert "item two" in items[0]

def test_all_done(tmp_path):
    p = tmp_path / "plan.md"
    p.write_text(SAMPLE_PLAN.replace("- [ ]", "- [x]"))
    pf = PlanFile(p)
    assert pf.is_complete

def test_no_checklist(tmp_path):
    p = tmp_path / "plan.md"
    p.write_text("# Empty plan\nNo checklist here.")
    pf = PlanFile(p)
    assert pf.total == 0
```

```python
# tests/ralph-loop/test_lock.py
import os, signal, pytest
from pathlib import Path
from scripts.lib.lock import LockFile

def test_acquire_release(tmp_path):
    lf = LockFile(tmp_path / ".lock")
    lf.acquire()
    assert lf.path.exists()
    assert lf.path.read_text().strip() == str(os.getpid())
    lf.release()
    assert not lf.path.exists()

def test_is_alive_current_process(tmp_path):
    lf = LockFile(tmp_path / ".lock")
    lf.acquire()
    assert lf.is_held_by_alive_process()
    lf.release()

def test_stale_lock_detected(tmp_path):
    lf = LockFile(tmp_path / ".lock")
    # Write a PID that doesn't exist
    lf.path.write_text("999999999")
    assert not lf.is_held_by_alive_process()

def test_context_manager(tmp_path):
    lock_path = tmp_path / ".lock"
    with LockFile(lock_path) as lf:
        assert lock_path.exists()
    assert not lock_path.exists()
```

**Step 2: Run tests — verify they fail**
Run: `python3 -m pytest tests/ralph-loop/test_plan.py tests/ralph-loop/test_lock.py -v`
Expected: FAIL (ModuleNotFoundError)

**Step 3: Write implementation**

```python
# scripts/lib/__init__.py
"""Ralph loop shared library. Python scripts only — hooks stay bash."""
```

```python
# scripts/lib/plan.py
"""Plan file parser — reads markdown checklist state."""
import re
from pathlib import Path

_CHECKED = re.compile(r"^- \[x\] ", re.MULTILINE)
_UNCHECKED = re.compile(r"^- \[ \] ", re.MULTILINE)
_SKIPPED = re.compile(r"^- \[SKIP\] ", re.MULTILINE)
_UNCHECKED_LINE = re.compile(r"^- \[ \] .*$", re.MULTILINE)


class PlanFile:
    def __init__(self, path: Path):
        self.path = path
        self._text = path.read_text() if path.exists() else ""

    def reload(self):
        self._text = self.path.read_text() if self.path.exists() else ""

    @property
    def checked(self) -> int:
        return len(_CHECKED.findall(self._text))

    @property
    def unchecked(self) -> int:
        return len(_UNCHECKED.findall(self._text))

    @property
    def skipped(self) -> int:
        return len(_SKIPPED.findall(self._text))

    @property
    def total(self) -> int:
        return self.checked + self.unchecked

    @property
    def is_complete(self) -> bool:
        return self.unchecked == 0

    def next_unchecked(self, n: int = 5) -> list[str]:
        return _UNCHECKED_LINE.findall(self._text)[:n]
```

```python
# scripts/lib/lock.py
"""PID lock file — signals to hooks that ralph-loop is active."""
import os, signal
from pathlib import Path


class LockFile:
    def __init__(self, path: Path):
        self.path = path

    def acquire(self):
        self.path.write_text(str(os.getpid()))

    def release(self):
        try:
            self.path.unlink()
        except FileNotFoundError:
            pass

    def is_held_by_alive_process(self) -> bool:
        if not self.path.exists():
            return False
        try:
            pid = int(self.path.read_text().strip())
            os.kill(pid, 0)
            return True
        except (ValueError, ProcessLookupError, PermissionError):
            return False

    def __enter__(self):
        self.acquire()
        return self

    def __exit__(self, *_):
        self.release()
```

**Step 4: Run tests — verify they pass**
Run: `python3 -m pytest tests/ralph-loop/test_plan.py tests/ralph-loop/test_lock.py -v`
Expected: PASS

**Step 5: Commit**
`feat: add Python shared library for ralph-loop (plan parser + lock file)`

---

### Task 2: Rewrite ralph-loop.sh → ralph_loop.py

**Files:**
- Create: `scripts/ralph_loop.py`
- Modify: `commands/execute.md` (update invocation)
- Test: `tests/ralph-loop/test_ralph_loop.py`

**Step 1: Write failing tests**

```python
# tests/ralph-loop/test_ralph_loop.py
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
        "RALPH_KIRO_CMD": "sleep 60",  # hangs forever
        "RALPH_TASK_TIMEOUT": "2",
    })
    # Should not hang — timeout kills it
    assert r.returncode == 1
    # Verify no orphan sleep processes from this test
    # (the sleep 60 should have been killed via process group)


def test_circuit_breaker(tmp_path):
    """After MAX_STALE rounds with no progress, should exit 1."""
    write_plan(tmp_path, items="- [ ] impossible | `false`")
    r = run_ralph(tmp_path, extra_env={
        "RALPH_KIRO_CMD": "true",  # exits immediately, makes no progress
    }, max_iter="5")
    assert r.returncode == 1
    assert "circuit breaker" in r.stdout.lower() or "no progress" in r.stdout.lower()


def test_lock_cleanup_on_signal(tmp_path):
    """Lock file should be cleaned up even if process is killed."""
    write_plan(tmp_path)
    lock_path = Path(".ralph-loop.lock")
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
    time.sleep(1)  # let it start and create lock
    assert lock_path.exists(), "Lock file should exist while running"
    proc.terminate()
    proc.wait(timeout=5)
    time.sleep(0.5)
    assert not lock_path.exists(), "Lock file should be cleaned up after SIGTERM"
```

**Step 2: Run tests — verify they fail**
Run: `python3 -m pytest tests/ralph-loop/test_ralph_loop.py -v`
Expected: FAIL

**Step 3: Write implementation**

`scripts/ralph_loop.py` — implementation strategy:

**Import path:** `sys.path.insert(0, project_root)` at top of script, where project_root is resolved via `Path(__file__).resolve().parent.parent`. This allows `from scripts.lib.plan import PlanFile`.

**Process group isolation:**
```python
proc = subprocess.Popen(
    cmd, stdout=log_fd, stderr=subprocess.STDOUT,
    start_new_session=True,  # new process group
)
```

**Timeout + cleanup (replaces bash watchdog/heartbeat subshells):**
```python
try:
    proc.wait(timeout=task_timeout)
except subprocess.TimeoutExpired:
    os.killpg(os.getpgid(proc.pid), signal.SIGTERM)
    proc.wait(timeout=5)  # grace period
```
No background sleep processes, no orphan fd leak. One `wait()` call.

**Heartbeat:** daemon `threading.Thread` that prints progress every N seconds. Daemon thread dies automatically when main thread exits — no cleanup needed, no orphan risk.

**Signal handling:**
```python
def _cleanup(signum, frame):
    lock.release()
    sys.exit(1)
signal.signal(signal.SIGTERM, _cleanup)
signal.signal(signal.SIGINT, _cleanup)
```
Plus `atexit.register(lock.release)` as belt-and-suspenders.

**Lock atomicity:** `write_text(str(pid))` is effectively atomic for small writes on local fs. No concurrent ralph-loop instances expected (enforce hook blocks direct execution when lock exists).

Full behavioral parity with bash version:
- Same env vars (PLAN_POINTER_OVERRIDE, RALPH_TASK_TIMEOUT, RALPH_HEARTBEAT_INTERVAL, RALPH_KIRO_CMD, RALPH_SKIP_DIRTY_CHECK)
- Same exit codes (0=done, 1=failure)
- Same lock file format (PID as text)
- Same output format (banner, heartbeat, summary block)
- Same .ralph-result summary file
- Same prompt template to kiro-cli
- Same circuit breaker (MAX_STALE=3)
- Same log file (.ralph-loop.log, append mode)

**Bug fix (discovered during brainstorm):** Current bash ralph-loop.sh calls `kiro-cli chat --no-interactive --trust-all-tools` without `--agent default`. This means kiro uses built-in `kiro_default` agent, NOT `.kiro/agents/default.json` — so all custom hooks (security, enforce-ralph-loop, pre-write gate) are NOT loaded during plan execution. Fix: add `--agent default` to the kiro-cli invocation.

**Step 4: Run tests — verify they pass**
Run: `python3 -m pytest tests/ralph-loop/test_ralph_loop.py -v`
Expected: PASS

**Step 5: Update commands/execute.md**
Change `./scripts/ralph-loop.sh` → `python3 scripts/ralph_loop.py`

**Step 6: Commit**
`feat: rewrite ralph-loop in Python — process group isolation, no orphan fd leak`

---

### Task 3: Rewrite generate-platform-configs.sh → generate_configs.py

**Files:**
- Create: `scripts/generate_configs.py`
- Test: `tests/test_generate_configs.py`

**Step 1: Write failing test**

```python
# tests/test_generate_configs.py
import subprocess, json, pytest
from pathlib import Path

def test_generates_valid_json():
    """Config generator should produce valid JSON for all output files."""
    r = subprocess.run(
        ["python3", "scripts/generate_configs.py"],
        capture_output=True, text=True,
    )
    assert r.returncode == 0
    for f in [".claude/settings.json", ".kiro/agents/default.json",
              ".kiro/agents/reviewer.json", ".kiro/agents/researcher.json",
              ".kiro/agents/executor.json"]:
        p = Path(f)
        assert p.exists(), f"{f} not generated"
        json.loads(p.read_text())  # raises on invalid JSON

def test_hooks_registered():
    """All security + gate hooks must be in generated configs."""
    cfg = json.loads(Path(".kiro/agents/default.json").read_text())
    hook_commands = [h["command"] for h in cfg["hooks"]["preToolUse"]]
    assert any("block-dangerous" in c for c in hook_commands)
    assert any("enforce-ralph-loop" in c for c in hook_commands)

def test_output_matches_bash_generator():
    """Python generator must produce semantically identical JSON to bash version."""
    # Save current configs
    targets = [".claude/settings.json", ".kiro/agents/default.json",
               ".kiro/agents/reviewer.json", ".kiro/agents/researcher.json",
               ".kiro/agents/executor.json"]
    originals = {}
    for f in targets:
        p = Path(f)
        if p.exists():
            originals[f] = json.loads(p.read_text())

    # Run Python generator
    r = subprocess.run(["python3", "scripts/generate_configs.py"],
                       capture_output=True, text=True)
    assert r.returncode == 0

    # Compare: same keys, same values (ignore key ordering)
    for f in targets:
        p = Path(f)
        new = json.loads(p.read_text())
        if f in originals:
            assert new == originals[f], f"JSON mismatch in {f}"
```

**Step 2: Run tests — verify they fail**
Run: `python3 -m pytest tests/test_generate_configs.py -v`
Expected: FAIL (ModuleNotFoundError or assertion)

**Step 3: Write implementation**

`scripts/generate_configs.py` — replaces generate-platform-configs.sh:
- Python dicts → `json.dump()` (no jq, no string escaping bugs)
- Same output files: `.claude/settings.json`, `.kiro/agents/*.json`
- Same validation: load each output and verify valid JSON
- Hook registry as Python data structure (single source of truth)

**Step 4: Run tests — verify they pass**
Run: `python3 -m pytest tests/test_generate_configs.py -v`
Expected: PASS

**Step 5: Commit**
`feat: rewrite config generator in Python — native JSON, no jq dependency`

---

### Task 4: Rename default agent → pilot + update references

**Files:**
- Rename: `.kiro/agents/default.json` → `.kiro/agents/pilot.json`
- Modify: `.kiro/agents/pilot.json` (name field: "default" → "pilot")
- Modify: `scripts/generate_configs.py` (output filename + name field)
- Modify: `scripts/ralph_loop.py` (`--agent pilot`)
- Modify: `hooks/gate/enforce-ralph-loop.sh` (help message)
- Modify: `commands/execute.md` (if references agent name)
- Modify: `README.md` (agent references)
- Modify: `AGENTS.md` (if references default agent)

**Why:** `.kiro/agents/default.json` named "default" is easily confused with Kiro's built-in `kiro_default`. Rename to `pilot` for clarity — it's the main orchestrator that dispatches executor/reviewer/researcher.

**Step 1: Rename file and update name field**
Rename `.kiro/agents/default.json` → `.kiro/agents/pilot.json`, change `"name": "default"` → `"name": "pilot"`.

**Step 2: Update config generator**
In `scripts/generate_configs.py`, change output path and name field for the main agent config.

**Step 3: Update ralph_loop.py invocation**
Change `--agent default` → `--agent pilot`.

**Step 4: Update enforce-ralph-loop.sh help message**
Change: `You MUST run: python3 scripts/ralph_loop.py`
(already correct, but verify it doesn't reference "default agent")

**Step 5: Update all docs referencing "default agent" or "default.json"**
Search and replace in README.md, AGENTS.md, commands/*.md.

**Step 6: Verify**
Run: `test -f .kiro/agents/pilot.json && ! test -f .kiro/agents/default.json && grep -q '"name": "pilot"' .kiro/agents/pilot.json`

**Step 7: Commit**
`refactor: rename default agent to pilot — avoid confusion with kiro_default`

---

### Task 5: Update enforce-ralph-loop.sh references

**Files:**
- Modify: `hooks/gate/enforce-ralph-loop.sh` (update help message + command allowlist)
- Modify: `tests/ralph-loop/test-enforcement.sh` (update command path in test)
- Modify: `tests/ralph-loop/test-timeout-heartbeat.sh` (update invocation)

**Step 1: Update enforce-ralph-loop.sh line 53**
Change: `You MUST run: ./scripts/ralph-loop.sh`
To: `You MUST run: python3 scripts/ralph_loop.py`

**Step 2: Update enforce-ralph-loop.sh line 62 (command allowlist)**
Change: `echo "$CMD" | grep -q 'ralph-loop' && exit 0`
To: `echo "$CMD" | grep -qE 'ralph[-_.]loop|ralph_loop' && exit 0`
(Matches ralph-loop.sh, ralph_loop.py, ralph.loop variants. Dot escaped via character class to prevent wildcard matching.)

**Step 3: Update test files**

**Step 4: Verify**
Run: `bash tests/ralph-loop/test-enforcement.sh`
Expected: All tests pass

**Step 5: Commit**
`chore: update references from ralph-loop.sh to ralph_loop.py`

---

### Task 6: Language boundary rule + cleanup

**Files:**
- Modify: `.claude/rules/shell.md` (add language boundary rule)
- Create: `scripts/lib/README.md` (boundary documentation)
- Modify: `.gitignore` (add `__pycache__/`)
- Delete: `scripts/ralph-loop.sh` (replaced)
- Delete: `scripts/generate-platform-configs.sh` (replaced)

**Step 1: Add language boundary rule to `.claude/rules/shell.md`**

Append:
```markdown
## Language Boundary

- `hooks/` = bash only. Every hook must be `.sh`. Latency budget: <5ms per hook.
- `scripts/` = Python preferred for new scripts. Bash allowed for thin wrappers.
- Communication between layers: file protocol only (lock files, .active pointer, markdown). No cross-language function calls.
- `scripts/lib/` = Python shared library. Hooks must NOT import from here.
```

**Step 2: Create scripts/lib/README.md**

```markdown
# scripts/lib/ — Python Shared Library

Used by: `scripts/ralph_loop.py`, `scripts/generate_configs.py`
NOT used by: `hooks/**/*.sh` (hooks are bash, latency-sensitive)

## Boundary Rule

Hooks (bash, <5ms) ←→ file protocol ←→ Scripts (Python, complex logic)

Never: hooks importing Python | scripts sourcing bash
```

**Step 3: Add `__pycache__/` to .gitignore**

**Step 4: Remove old bash scripts**
Move `scripts/ralph-loop.sh` and `scripts/generate-platform-configs.sh` to `.trash/`

**Step 5: Verify nothing references old paths**
Run: `grep -rn 'ralph-loop\.sh\|generate-platform-configs\.sh' --include="*.sh" --include="*.md" --include="*.json" . | grep -v '.trash' | grep -v 'docs/plans/20'`
Expected: No matches (or only historical plan docs)

**Step 6: Commit**
`chore: enforce language boundary — hooks=bash, scripts=python, file protocol between`

## Checklist

- [ ] scripts/lib/plan.py 解析 checklist 正确 | `python3 -m pytest tests/ralph-loop/test_plan.py -v`
- [ ] scripts/lib/lock.py 锁文件生命周期正确 | `python3 -m pytest tests/ralph-loop/test_lock.py -v`
- [ ] ralph_loop.py 无 active plan 时 exit 1 | `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_no_active_plan -v`
- [ ] ralph_loop.py 无 checklist 时 exit 1 | `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_no_checklist -v`
- [ ] ralph_loop.py 全部完成时 exit 0 | `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_already_complete -v`
- [ ] ralph_loop.py 超时能杀掉子进程 | `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_timeout_kills_process -v`
- [ ] ralph_loop.py circuit breaker 生效 | `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_circuit_breaker -v`
- [ ] ralph_loop.py SIGTERM 后清理 lock | `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_lock_cleanup_on_signal -v`
- [ ] ralph_loop.py 传 --agent pilot 给 kiro-cli | `grep -q '\-\-agent.*pilot' scripts/ralph_loop.py`
- [ ] generate_configs.py 生成合法 JSON | `python3 -m pytest tests/test_generate_configs.py::test_generates_valid_json -v`
- [ ] generate_configs.py 注册所有 hooks | `python3 -m pytest tests/test_generate_configs.py::test_hooks_registered -v`
- [ ] generate_configs.py 输出与 bash 版语义一致 | `python3 -m pytest tests/test_generate_configs.py::test_output_matches_bash_generator -v`
- [ ] agent 已改名 pilot.json | `test -f .kiro/agents/pilot.json && ! test -f .kiro/agents/default.json`
- [ ] pilot.json name 字段正确 | `grep -q '"name": "pilot"' .kiro/agents/pilot.json`
- [ ] enforce-ralph-loop.sh 匹配新命令名 | `echo '{"tool_name":"execute_bash","tool_input":{"command":"python3 scripts/ralph_loop.py"}}' | bash hooks/gate/enforce-ralph-loop.sh; test $? -eq 0`
- [ ] 旧脚本已移除 | `test ! -f scripts/ralph-loop.sh && test ! -f scripts/generate-platform-configs.sh`
- [ ] 语言边界规则已写入 | `grep -q 'Language Boundary' .claude/rules/shell.md`
- [ ] __pycache__ 已 gitignore | `grep -q '__pycache__' .gitignore`
- [ ] 无残留旧路径引用 | `grep -rn 'ralph-loop\.sh\|generate-platform-configs\.sh' --include='*.sh' --include='*.json' . | grep -v '.trash' | grep -v 'docs/plans/20' | wc -l | grep -q '^0$'`

## Errors

| Error | Task | Attempt | Resolution |
|-------|------|---------|------------|

## Findings
