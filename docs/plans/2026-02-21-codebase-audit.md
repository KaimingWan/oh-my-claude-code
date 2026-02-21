# Codebase Audit — 全面代码审查

**Goal:** 修复代码中的类型错误、不一致、冗余、潜在 bug 和死代码，提升代码质量和可维护性
**Non-Goals:** 不做功能变更、不改架构、不加新特性、不改 shell hook 的业务逻辑
**Architecture:** 逐模块修复，Python 先行（有类型系统保障），shell 后行（靠测试保障）
**Tech Stack:** Python 3.14, Bash, Pyright, pytest

## Tasks

### Task 1: Python 类型错误修复

修复 Pyright 报告的 6 个类型错误。

**Files:**
- Modify: `scripts/ralph_loop.py`
- Modify: `scripts/lib/pty_runner.py`
- Test: `tests/ralph-loop/test_ralph_loop.py`

**What to implement:**
1. `ralph_loop.py:176` — `Config.plan_pointer: Path = None` → `Path | None = None`
2. `ralph_loop.py:37` — `make_cleanup_handler(shutdown_flag: list = None)` → `list | None = None`
3. `ralph_loop.py:183` — `parse_config(argv: list[str] = None)` → `list[str] | None = None`
4. `ralph_loop.py:227` — `child_proc_ref = [None]` → 类型注解 `list[subprocess.Popen | None]`
5. `ralph_loop.py:61` — `_heartbeat(log_path: Path = None)` → `Path | None = None`
6. `pty_runner.py:9` — 返回类型 `callable` → `Callable` 或移除（用 `typing.Callable`）

**Verify:** `cd /Users/wanshao/project/oh-my-claude-code && python3 -m pyright scripts/ralph_loop.py scripts/lib/pty_runner.py 2>&1 | grep -c 'error' | grep -q '^0$'`

### Task 2: 死代码清理

移除生产代码中无调用的函数（仅测试引用的保留但标记 deprecation 注释）。

**Files:**
- Modify: `scripts/lib/plan.py`
- Modify: `scripts/lib/lock.py`
- Modify: `scripts/ralph_loop.py`
- Test: `tests/ralph-loop/test_ralph_loop.py`

**What to implement:**
1. `validate_plan()` 在 `ralph_loop.py` 中定义但 `main()` 未使用（内联了同样逻辑）→ 让 `main()` 调用 `validate_plan()` 消除重复
2. `LockFile.is_held_by_alive_process()` — 零引用 → 添加 `# Used by external callers` 注释保留（可能被项目外使用）
3. `PlanFile.check_off()` — 仅测试引用 → 保留，添加注释说明用途
4. `PlanFile.verify_and_check_all()` — 仅自身定义引用 → 保留，添加注释说明用途

**Verify:** `cd /Users/wanshao/project/oh-my-claude-code && python3 -c "from scripts.ralph_loop import validate_plan, main; from scripts.lib.plan import PlanFile; from scripts.lib.lock import LockFile" && echo ok`

### Task 3: detect_test_command 双实现统一

`hooks/_lib/common.sh` 和 `scripts/lib/precheck.py` 各有一份 `detect_test_command`，检测逻辑不一致。

**Files:**
- Modify: `hooks/_lib/common.sh`
- Modify: `scripts/lib/precheck.py`
- Test: `tests/ralph-loop/test_precheck.py`

**What to implement:**
1. 统一 Python 版用 `python3 -m pytest`（当前正确），shell 版从 `python -m pytest` 改为 `python3 -m pytest`
2. Python 版缺少 pom.xml/gradle/Makefile 检测 → 添加（与 shell 版对齐）
3. Shell 版缺少 conftest.py 检测 → 添加（与 Python 版对齐）

**Verify:** `cd /Users/wanshao/project/oh-my-claude-code && grep -q 'python3 -m pytest' hooks/_lib/common.sh && grep -q 'conftest.py' hooks/_lib/common.sh && grep -q 'pom.xml' scripts/lib/precheck.py && echo ok`

### Task 4: 危险命令列表统一

`generate_configs.py` 的 `DENIED_COMMANDS_STRICT` 和 `hooks/_lib/patterns.sh` 的 `DANGEROUS_BASH_PATTERNS` 是两套独立维护的列表，内容有差异。

**Files:**
- Modify: `scripts/generate_configs.py`
- Test: `tests/test_generate_configs.py`

**What to implement:**
1. 在 `generate_configs.py` 的 `DENIED_COMMANDS_STRICT` 中添加 patterns.sh 有但它缺少的：`shred`, `dd.*of=/`, `docker system prune`, `docker rm -f`, `docker rmi -f`
2. 添加代码注释说明两个列表的关系：DENIED_COMMANDS_STRICT 用于 Kiro agent config 的 deniedCommands（正则），patterns.sh 用于 hook 运行时检测（grep 正则）。两者应保持同步。

**Verify:** `cd /Users/wanshao/project/oh-my-claude-code && python3 -c "from scripts.generate_configs import DENIED_COMMANDS_STRICT; patterns = ' '.join(DENIED_COMMANDS_STRICT); assert 'shred' in patterns and 'docker' in patterns" && echo ok`

### Task 5: Shell hook 冗余消除 — WS_HASH 抽取

`WS_HASH=$(pwd | shasum 2>/dev/null | cut -c1-8 || echo "default")` 在 7+ 个 hook 中重复。抽取到 `_lib/common.sh`。

**Files:**
- Modify: `hooks/_lib/common.sh`
- Modify: `hooks/feedback/context-enrichment.sh`
- Modify: `hooks/feedback/post-bash.sh`
- Modify: `hooks/feedback/verify-completion.sh`
- Modify: `hooks/feedback/auto-capture.sh`
- Modify: `hooks/feedback/correction-detect.sh`
- Modify: `hooks/feedback/session-init.sh`
- Modify: `hooks/feedback/kb-health-report.sh`
- Modify: `hooks/gate/pre-write.sh`
- Modify: `hooks/_lib/block-recovery.sh`
- Test: `tests/hooks/test-context-budget.sh`

**What to implement:**
1. 在 `hooks/_lib/common.sh` 添加 `ws_hash()` 函数
2. 所有 hook 中的内联 WS_HASH 计算替换为调用 `ws_hash`

**Verify:** `cd /Users/wanshao/project/oh-my-claude-code && grep -q 'ws_hash()' hooks/_lib/common.sh && ! grep -rn 'shasum.*cut -c1-8' hooks/feedback/ hooks/gate/ hooks/_lib/block-recovery.sh | grep -v 'common.sh' | grep -q . && echo ok`

### Task 6: plan.py 语义问题修复

`total` 属性不含 skipped，但 `is_complete` 只检查 `unchecked == 0`。全部 SKIP 时报 "All tasks complete" 而非 "All tasks skipped"。

**Files:**
- Modify: `scripts/lib/plan.py`
- Modify: `scripts/ralph_loop.py`
- Test: `tests/ralph-loop/test_plan.py`

**What to implement:**
1. `PlanFile` 添加 `is_all_skipped` 属性：`self.unchecked == 0 and self.checked == 0 and self.skipped > 0`
2. `ralph_loop.py` 的完成检查中区分 complete vs all-skipped，输出不同消息

**Verify:** `cd /Users/wanshao/project/oh-my-claude-code && python3 -c "
from pathlib import Path; import tempfile, os
d = tempfile.mkdtemp()
p = Path(d)/'test.md'
p.write_text('## Checklist\n- [SKIP] a\n- [SKIP] b\n')
from scripts.lib.plan import PlanFile
pf = PlanFile(p)
assert pf.is_complete
assert hasattr(pf, 'is_all_skipped') and pf.is_all_skipped
print('ok')
"`

### Task 7: pty_runner.py fd 泄漏修复

`master` fd 只在 `_reader` 线程中关闭。如果线程因 `stop_event` 提前退出，fd 泄漏。

**Files:**
- Modify: `scripts/lib/pty_runner.py`
- Test: `tests/ralph-loop/test_pty_runner.py`

**What to implement:**
1. `stop()` 函数中添加 `master` fd 的 fallback 关闭：`try: os.close(master) except OSError: pass`
2. 用 `threading.Event` + fd 状态标记确保不会双重关闭

**Verify:** `cd /Users/wanshao/project/oh-my-claude-code && python3 -m pytest tests/ralph-loop/test_pty_runner.py -v 2>&1 | tail -1 | grep -q 'passed'`

## Checklist

- [x] Pyright 类型错误全部修复（0 errors） | `cd /Users/wanshao/project/oh-my-claude-code && python3 -m pyright scripts/ralph_loop.py scripts/lib/pty_runner.py 2>&1 | grep '0 errors' | grep -q '0 errors'`
- [x] validate_plan() 被 main() 调用，消除重复逻辑 | `cd /Users/wanshao/project/oh-my-claude-code && python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_validate_plan_missing -v 2>&1 | grep -q 'PASSED'`
- [x] detect_test_command 两个实现对齐 | `cd /Users/wanshao/project/oh-my-claude-code && grep -q 'python3 -m pytest' hooks/_lib/common.sh && grep -q 'conftest.py' hooks/_lib/common.sh && grep -q 'pom.xml' scripts/lib/precheck.py && echo ok`
- [x] 危险命令列表补齐 docker/shred | `cd /Users/wanshao/project/oh-my-claude-code && python3 -c "from scripts.generate_configs import DENIED_COMMANDS_STRICT; p=' '.join(DENIED_COMMANDS_STRICT); assert 'shred' in p and 'docker' in p" && echo ok`
- [x] WS_HASH 抽取为 ws_hash() 函数，旧内联用法全部替换 | `cd /Users/wanshao/project/oh-my-claude-code && grep -q 'ws_hash()' hooks/_lib/common.sh && test "$(grep -rn 'pwd | shasum' hooks/feedback/ hooks/gate/ hooks/_lib/block-recovery.sh | grep -vc 'common.sh')" = "0" && echo ok`
- [x] plan.py is_all_skipped 属性行为正确 | `cd /Users/wanshao/project/oh-my-claude-code && python3 -m pytest tests/ralph-loop/test_plan.py -k 'skip' -v 2>&1 | grep -q 'passed'`
- [x] pty_runner.py fd 泄漏修复 + 测试通过 | `cd /Users/wanshao/project/oh-my-claude-code && python3 -m pytest tests/ralph-loop/test_pty_runner.py -v 2>&1 | tail -1 | grep -q 'passed'`
- [x] 回归测试通过 | `python3 -m pytest tests/ralph-loop/ -v`

## Review

Round 1: Goal Alignment ✅ APPROVE | Verify Correctness ❌ REQUEST CHANGES | Completeness ❌ REQUEST CHANGES | Technical Feasibility ✅ APPROVE
→ Verify Correctness findings discarded after verification: (1) pyright IS installed (1.1.408), (2) checklist item 5 grep pattern is correct (counts non-common.sh matches), (3) test_validate_plan_missing already exists
→ Completeness finding discarded: session-init.sh and kb-health-report.sh ARE in Task 5 file list
**Effective: 4/4 APPROVE after fact-checking**

## Errors

| Error | Task | Attempt | Resolution |
|-------|------|---------|------------|
