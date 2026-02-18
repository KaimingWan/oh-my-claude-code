# Ralph Loop Context Optimization

**Goal:** Eliminate context waste in Ralph Loop by isolating state files per plan, adding environment pre-check, and differentiating first iteration from subsequent ones — so each iteration's agent gets only high-signal context.

**Non-Goals:** Not changing plan file format (stays Markdown). Not adding CC-only features (Agent Teams, PreCompact). Not changing hook architecture.

**Architecture:** Three changes to `ralph_loop.py`: (1) progress/findings files derived from plan path instead of global shared files, (2) environment pre-check runs test suite before each iteration and injects result into prompt, (3) iteration 1 gets a distinct "initializer" prompt that verifies environment before implementing. All changes in `scripts/ralph_loop.py` + `scripts/lib/` + tests.

**Tech Stack:** Python 3, pytest

## Review

Round 1 (4 reviewers parallel):
- Goal Alignment: APPROVE — all tasks map to goal phrases, execution order valid
- Verify Correctness: APPROVE — 9/9 verify commands sound (different exit codes for correct vs broken)
- Completeness: APPROVE — all modified functions covered by tasks
- Technical Feasibility: APPROVE — no blockers, stdlib dependencies only

Post-review fix: added `build_batch_prompt` parallel branch coverage to Task 1 + checklist.

## Tasks

### Task 1: Plan-scoped State Files

**Files:**
- Modify: `scripts/lib/plan.py`
- Modify: `scripts/ralph_loop.py`
- Test: `tests/ralph-loop/test_plan.py`

**Verify:** `python3 -m pytest tests/ralph-loop/test_plan.py::test_state_files_scoped_to_plan -v`

**Step 1: Write failing test**

In `tests/ralph-loop/test_plan.py`:
```python
def test_state_files_scoped_to_plan(tmp_path):
    plan = tmp_path / "2026-01-01-my-feature.md"
    plan.write_text("# Test\n## Checklist\n- [ ] item | `true`\n")
    pf = PlanFile(plan)
    assert pf.progress_path == tmp_path / "2026-01-01-my-feature.progress.md"
    assert pf.findings_path == tmp_path / "2026-01-01-my-feature.findings.md"
```

**Step 2: Run test — verify it fails**
Run: `python3 -m pytest tests/ralph-loop/test_plan.py::test_state_files_scoped_to_plan -v`
Expected: FAIL

**Step 3: Implement**

In `scripts/lib/plan.py`, add to `PlanFile`:
```python
@property
def progress_path(self) -> Path:
    return self.path.parent / f"{self.path.stem}.progress.md"

@property
def findings_path(self) -> Path:
    return self.path.parent / f"{self.path.stem}.findings.md"
```

In `scripts/ralph_loop.py`, replace in `build_prompt()` and `build_batch_prompt()`:
```python
progress_file = plan.progress_path
findings_file = plan.findings_path
```

Also verify `build_batch_prompt` uses scoped paths in both parallel and sequential branches (lines ~153-175 in current code).

**Step 4: Run test — verify it passes**

**Step 5: Commit**

---

### Task 2: Environment Pre-check

**Files:**
- Create: `scripts/lib/precheck.py`
- Modify: `scripts/ralph_loop.py`
- Test: `tests/ralph-loop/test_precheck.py`

**Verify:** `python3 -m pytest tests/ralph-loop/test_precheck.py -v`

**Step 1: Write failing test**

Create `tests/ralph-loop/test_precheck.py`:
```python
from scripts.lib.precheck import detect_test_command, run_precheck
from pathlib import Path

def test_detect_pytest(tmp_path):
    (tmp_path / "pyproject.toml").write_text("[tool.pytest]\n")
    assert "pytest" in detect_test_command(tmp_path)

def test_detect_npm(tmp_path):
    (tmp_path / "package.json").write_text("{}\n")
    assert "npm test" in detect_test_command(tmp_path)

def test_detect_none(tmp_path):
    assert detect_test_command(tmp_path) == ""

def test_run_precheck_pass(tmp_path):
    (tmp_path / "pyproject.toml").write_text("")
    (tmp_path / "test_ok.py").write_text("def test_ok(): pass\n")
    ok, out = run_precheck(tmp_path)
    assert ok is True

def test_run_precheck_no_tests(tmp_path):
    ok, out = run_precheck(tmp_path)
    assert ok is True
    assert "No test command" in out
```

**Step 2: Run test — verify it fails**
Run: `python3 -m pytest tests/ralph-loop/test_precheck.py -v`
Expected: FAIL

**Step 3: Implement**

Create `scripts/lib/precheck.py`:
```python
"""Environment pre-check — detect and run project test suite."""
import subprocess
from pathlib import Path

def detect_test_command(project_root: Path) -> str:
    if (project_root / "pyproject.toml").exists() or (project_root / "pytest.ini").exists():
        return "python3 -m pytest -x -q"
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
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True,
                          timeout=timeout, cwd=project_root)
        lines = (r.stdout + r.stderr).strip().split('\n')
        return r.returncode == 0, '\n'.join(lines[-20:])
    except subprocess.TimeoutExpired:
        return False, f"Test timed out after {timeout}s"
```

In `ralph_loop.py`, import and call before prompt building, inject result into prompt.

**Step 4: Run test — verify it passes**

**Step 5: Commit**

---

### Task 3: Initializer Prompt for First Iteration

**Files:**
- Modify: `scripts/ralph_loop.py`
- Test: `tests/ralph-loop/test_ralph_loop.py`

**Verify:** `python3 -m pytest tests/ralph-loop/test_ralph_loop.py -k init_prompt -v`

**Step 1: Write failing test**

```python
def test_init_prompt_differs_from_regular(tmp_path, monkeypatch):
    plan_file = tmp_path / "plan.md"
    plan_file.write_text("# T\n## Checklist\n- [ ] a | `true`\n")
    import scripts.ralph_loop as rl
    monkeypatch.setattr(rl, 'plan', PlanFile(plan_file))
    monkeypatch.setattr(rl, 'plan_path', plan_file)
    init = rl.build_init_prompt()
    regular = rl.build_prompt(2)
    assert "FIRST iteration" in init
    assert "FIRST iteration" not in regular
```

**Step 2: Run test — verify it fails**
Expected: FAIL

**Step 3: Implement**

Add `build_init_prompt()` to `ralph_loop.py`. In main loop, use when `i == 1 and plan.checked == 0 and not batches`.

**Step 4: Run test — verify it passes**

**Step 5: Commit**

---

### Task 4: Regression

**Files:**
- Test: `tests/ralph-loop/test_ralph_loop.py`
- Test: `tests/ralph-loop/test_plan.py`

**Verify:** `python3 -m pytest tests/ralph-loop/ -v`

Run full regression. Fix any tests broken by path changes.

Expected: All pass

**Commit:** `test: update tests for scoped state files and precheck`

---

## Findings
<!-- Append-only during execution -->

## Errors

| Error | Task | Attempt | Resolution |
|-------|------|---------|------------|

## Checklist

- [x] PlanFile.progress_path 返回 plan-scoped 路径 | `python3 -c "from scripts.lib.plan import PlanFile; from pathlib import Path; p=PlanFile(Path('docs/plans/2026-02-19-ralph-loop-context-optimization.md')); assert p.progress_path.name == '2026-02-19-ralph-loop-context-optimization.progress.md'"`
- [x] PlanFile.findings_path 返回 plan-scoped 路径 | `python3 -c "from scripts.lib.plan import PlanFile; from pathlib import Path; p=PlanFile(Path('docs/plans/2026-02-19-ralph-loop-context-optimization.md')); assert p.findings_path.name == '2026-02-19-ralph-loop-context-optimization.findings.md'"`
- [x] build_prompt 使用 plan.progress_path | `grep -q 'plan\.progress_path\|plan\.findings_path' scripts/ralph_loop.py`
- [x] build_batch_prompt parallel 分支使用 scoped paths | `python3 -c "import scripts.ralph_loop as rl; src=open('scripts/ralph_loop.py').read(); assert 'plan.progress_path' in src and 'plan.findings_path' in src and src.count('plan.progress_path') >= 2"`
- [ ] detect_test_command 识别 pytest | `python3 -c "from scripts.lib.precheck import detect_test_command; from pathlib import Path; assert 'pytest' in detect_test_command(Path('.'))"`
- [ ] run_precheck 可执行 | `python3 -c "from scripts.lib.precheck import run_precheck; from pathlib import Path; ok, _ = run_precheck(Path('.')); print('ok' if isinstance(ok, bool) else 'FAIL')"`
- [ ] build_prompt 包含环境状态 | `grep -qE 'precheck|Environment' scripts/ralph_loop.py`
- [ ] build_init_prompt 存在 | `grep -q 'def build_init_prompt' scripts/ralph_loop.py`
- [ ] iteration 1 使用 init prompt | `grep -q 'build_init_prompt' scripts/ralph_loop.py`
- [ ] 回归测试通过 | `python3 -m pytest tests/ralph-loop/ -v`
