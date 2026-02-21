# Ralph Loop 执行效率优化

**Goal:** 减少 Ralph Loop 每次迭代的固定开销（实测 ~17-24s/迭代），提升代码稳定性和可维护性
**Non-Goals:** 改变 Ralph Loop 的核心架构（每次新 session = 干净 context）；改变 CLI 调用方式（session resume 已调研证伪）；改变 hook 系统
**Architecture:** 缓存 detect_cli 结果避免重复 ping；precheck 只跑一次；合并重复 prompt 函数；修复 pty_runner fd 所有权；简化 heartbeat 逻辑；claude 模式加 --no-session-persistence
**Tech Stack:** Python 3, pytest

## Tasks

### Task 1: detect_cli() 结果缓存

**Files:**
- Modify: `scripts/lib/cli_detect.py`
- Modify: `scripts/ralph_loop.py`
- Test: `tests/ralph-loop/test_ralph_loop.py`

**Step 1: Write failing test**
在 `test_ralph_loop.py` 中添加测试：验证 `detect_cli()` 在 main loop 中只被调用一次（通过检查源码中 detect_cli 在循环外调用）。

```python
def test_detect_cli_called_outside_loop():
    """detect_cli() must be called before the loop, not inside it."""
    source = open("scripts/ralph_loop.py").read()
    # Find the main loop: "for i in range(1, max_iterations + 1):"
    loop_start = source.index("for i in range(1, max_iterations + 1):")
    before_loop = source[:loop_start]
    in_loop = source[loop_start:]
    assert "detect_cli()" in before_loop, "detect_cli() should be called before the loop"
    assert "detect_cli()" not in in_loop, "detect_cli() should NOT be called inside the loop"
```

**Step 2: Run test — verify it fails**
Run: `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_detect_cli_called_outside_loop -v`
Expected: FAIL (detect_cli() is currently called inside the loop)

**Step 3: Write minimal implementation**
在 `ralph_loop.py` 的 `main()` 中，将 `detect_cli()` 调用移到循环之前，将结果存入 `base_cmd` 变量，循环内直接使用。

**Step 4: Run test — verify it passes**
Run: `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_detect_cli_called_outside_loop -v`
Expected: PASS

**Step 5: Commit**
`feat: cache detect_cli() result — save ~8s per iteration`

---

### Task 2: precheck 只跑一次

**Files:**
- Modify: `scripts/ralph_loop.py`
- Test: `tests/ralph-loop/test_ralph_loop.py`

**Step 1: Write failing test**
```python
def test_precheck_runs_only_once():
    """run_precheck should only appear in build_init_prompt, not build_prompt."""
    source = open("scripts/ralph_loop.py").read()
    # build_prompt should not call run_precheck at all
    build_prompt_body = source.split("def build_prompt(")[1].split("\ndef ")[0]
    assert "run_precheck" not in build_prompt_body, "build_prompt should not call run_precheck"
```

**Step 2: Run test — verify it fails**
Run: `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_precheck_runs_only_once -v`
Expected: FAIL (build_prompt currently calls run_precheck)

**Step 3: Write minimal implementation**
修改 `build_prompt()`：移除 `run_precheck()` 调用，env_status 始终为 "✅ Environment OK (cached)"。precheck 只在 `build_init_prompt()` 中执行。

**Step 4: Run test — verify it passes**
Run: `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_precheck_runs_only_once -v`
Expected: PASS

**Step 5: Commit**
`feat: precheck runs only on first iteration — save ~2s per subsequent iteration`

---

### Task 3: 合并 build_prompt 和 build_init_prompt

**Files:**
- Modify: `scripts/ralph_loop.py`
- Test: `tests/ralph-loop/test_ralph_loop.py`

**Step 1: Write failing test**
```python
def test_single_build_prompt_function():
    """Only one prompt builder function should exist (merged)."""
    source = open("scripts/ralph_loop.py").read()
    assert "def build_init_prompt(" not in source, "build_init_prompt should be merged into build_prompt"
    assert "def build_prompt(" in source, "build_prompt should still exist"
```

**Step 2: Run test — verify it fails**
Run: `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_single_build_prompt_function -v`
Expected: FAIL (build_init_prompt still exists)

**Step 3: Write minimal implementation**
合并 `build_init_prompt()` 到 `build_prompt()` 中，增加 `is_first: bool = False` 参数。更新 `main()` 中的调用点。**必须同时更新** `test_init_prompt_differs_from_regular`：移除 `from scripts.ralph_loop import build_init_prompt`，改为调用 `build_prompt(is_first=True)` vs `build_prompt(is_first=False)` 并验证 "FIRST iteration" 文本差异。

**Step 4: Run test — verify it passes**
Run: `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_single_build_prompt_function -v`
Expected: PASS

**Step 5: Commit**
`refactor: merge build_init_prompt into build_prompt — reduce 30 lines of duplication`

---

### Task 4: pty_runner fd 所有权修复

**Files:**
- Modify: `scripts/lib/pty_runner.py`
- Test: `tests/ralph-loop/test_pty_runner.py`

**Step 1: Write failing test**
```python
def test_master_fd_single_close(tmp_path):
    """master fd should only be closed once (by reader thread), not double-closed."""
    import scripts.lib.pty_runner as mod
    source = open(mod.__file__).read()
    # stop() should not close master — reader owns it
    stop_body = source.split("def stop():")[1].split("\n    return")[0]
    assert "os.close(master)" not in stop_body, "stop() should not close master fd — reader thread owns it"
```

**Step 2: Run test — verify it fails**
Run: `python3 -m pytest tests/ralph-loop/test_pty_runner.py::test_master_fd_single_close -v`
Expected: FAIL (stop() currently closes master)

**Step 3: Write minimal implementation**
修改 `pty_run()`：从 `stop()` 中移除 `os.close(master)`，让 `_reader()` 线程独占 master fd 的关闭权。

**Step 4: Run test — verify it passes**
Run: `python3 -m pytest tests/ralph-loop/test_pty_runner.py::test_master_fd_single_close -v`
Expected: PASS

**Step 5: Commit**
`fix: pty_runner single fd ownership — eliminate double-close race`

---

### Task 5: heartbeat 逻辑简化

**Files:**
- Modify: `scripts/ralph_loop.py`
- Test: `tests/ralph-loop/test_ralph_loop.py`

**Step 1: Write failing test**
```python
def test_heartbeat_no_confusing_elapsed():
    """_heartbeat should not have the confusing elapsed calculation."""
    source = open("scripts/ralph_loop.py").read()
    assert "heartbeat_interval * (idle_elapsed // heartbeat_interval" not in source, \
        "Confusing elapsed calculation should be removed from _heartbeat"
```

**Step 2: Run test — verify it fails**
Run: `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_heartbeat_no_confusing_elapsed -v`
Expected: FAIL

**Step 3: Write minimal implementation**
简化 `_heartbeat()`：移除 `elapsed` 变量和混乱的计算逻辑。心跳只打印 `checked/total`，idle watchdog 只跟踪 `idle_elapsed`。

**Step 4: Run test — verify it passes**
Run: `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_heartbeat_no_confusing_elapsed -v`
Expected: PASS

**Step 5: Commit**
`fix: simplify heartbeat — remove confusing elapsed calculation`

---

### Task 6: claude 模式加 --no-session-persistence

**Files:**
- Modify: `scripts/lib/cli_detect.py`
- Test: `tests/ralph-loop/test_ralph_loop.py`

**Step 1: Write failing test**
```python
def test_claude_cmd_has_no_session_persistence():
    """Claude command should include --no-session-persistence to avoid disk I/O."""
    from scripts.lib.cli_detect import detect_cli
    from unittest.mock import patch
    import subprocess
    with patch('shutil.which', side_effect=lambda x: '/usr/bin/claude' if x == 'claude' else None), \
         patch('subprocess.run') as mock_run:
        mock_run.return_value = subprocess.CompletedProcess(args=[], returncode=0, stdout='pong', stderr='')
        cmd = detect_cli()
        assert '--no-session-persistence' in cmd
```

**Step 2: Run test — verify it fails**
Run: `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_claude_cmd_has_no_session_persistence -v`
Expected: FAIL

**Step 3: Write minimal implementation**
在 `detect_cli()` 的 claude 返回值中加入 `'--no-session-persistence'`。

**Step 4: Run test — verify it passes**
Run: `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_claude_cmd_has_no_session_persistence -v`
Expected: PASS

**Step 5: Commit**
`feat: add --no-session-persistence to claude command — reduce disk I/O`

## Review

Round 1: Goal Alignment ✅ APPROVE | Verify Correctness ✅ APPROVE | Completeness ❌ REQUEST CHANGES (Task 3 breaks test import) | Performance ✅ APPROVE
→ Fixed: Task 3 Step 3 updated to explicitly update test_init_prompt_differs_from_regular
Round 2: Goal Alignment ✅ APPROVE | Verify Correctness ❌ REQUEST CHANGES (误判: ran verify commands before implementation)
→ Calibration: Verify Correctness finding discarded (expected pre-implementation state)

**Final Verdict: APPROVED**

## Checklist

- [x] detect_cli 在循环外调用 | `python3 -c "s=open('scripts/ralph_loop.py').read(); l=s.index('for i in range(1,'); print('PASS' if 'detect_cli()' not in s[l:] else 'FAIL')" | grep -q PASS`
- [x] precheck 只在首次迭代跑 | `python3 -c "s=open('scripts/ralph_loop.py').read(); b=s.split('def build_prompt(')[1].split('\ndef ')[0]; print('PASS' if 'run_precheck' not in b else 'FAIL')" | grep -q PASS`
- [x] build_init_prompt 已合并 | `python3 -c "s=open('scripts/ralph_loop.py').read(); print('PASS' if 'def build_init_prompt(' not in s else 'FAIL')" | grep -q PASS`
- [x] pty_runner stop() 不关 master fd | `python3 -c "s=open('scripts/lib/pty_runner.py').read(); stop=s.split('def stop():')[1].split('return')[0]; print('PASS' if 'os.close(master)' not in stop else 'FAIL')" | grep -q PASS`
- [ ] heartbeat 无混乱 elapsed 计算 | `python3 -c "s=open('scripts/ralph_loop.py').read(); print('PASS' if 'heartbeat_interval * (idle_elapsed' not in s else 'FAIL')" | grep -q PASS`
- [ ] claude 命令含 --no-session-persistence | `python3 -c "s=open('scripts/lib/cli_detect.py').read(); print('PASS' if 'no-session-persistence' in s else 'FAIL')" | grep -q PASS`
- [ ] 回归测试通过 | `python3 -m pytest tests/ralph-loop/ -v -m 'not slow'`

## Errors

| Error | Task | Attempt | Resolution |
|-------|------|---------|------------|

## Reviewer Feedback (Round 1)

### Completeness reviewer — REQUEST CHANGES
**Finding:** Task 3 removes `build_init_prompt` but `test_init_prompt_differs_from_regular` (test_ralph_loop.py:442) imports it. Plan mentions updating the test but doesn't specify how.

**Resolution:** Task 3 Step 3 updated — the test must be rewritten to call `build_prompt(is_first=True)` vs `build_prompt(is_first=False)` and verify the "FIRST iteration" text difference. The import line `from scripts.ralph_loop import build_init_prompt` must be removed.
