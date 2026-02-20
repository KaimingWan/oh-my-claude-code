# Ralph Loop 全面重构与加固

**Goal:** 全面重构 ralph_loop.py 及其 lib 模块，消除所有已知风险（竞态、孤儿进程、脏状态、静默失败），提升代码质量和可测试性。
**Non-Goals:** 不改变 ralph loop 的外部行为和 CLI 接口；不改变 plan 文件格式；不添加新功能（如 PR 创建、远程执行）。
**Architecture:** 将 ralph_loop.py 的 main() 拆分为独立可测试阶段（config → validate → loop → cleanup）。LockFile 改用 fcntl.flock 实现真互斥。WorktreeManager 修复 squash merge abort 逻辑并增加 git 操作重试。消除所有 hack 和静默失败路径。
**Tech Stack:** Python 3.10+, fcntl, subprocess, threading, pytest

## Tasks

### Task 1: LockFile 改用 fcntl.flock 真互斥

**Files:**
- Modify: `scripts/lib/lock.py`
- Test: `tests/ralph-loop/test_lock.py`

**Step 1: Write failing test**
新增 test_flock_mutual_exclusion, test_flock_release_allows_reacquire, test_flock_context_manager 三个测试。验证：两个进程不能同时持有锁；释放后可重新获取；context manager 正确工作。

**Step 2: Run test — verify it fails**
Run: `python3 -m pytest tests/ralph-loop/test_lock.py::test_flock_mutual_exclusion tests/ralph-loop/test_lock.py::test_flock_release_allows_reacquire tests/ralph-loop/test_lock.py::test_flock_context_manager -v`
Expected: FAIL (try_acquire 方法不存在)

**Step 3: Write minimal implementation**
重写 `scripts/lib/lock.py`：
- `acquire()`: 打开文件 → `fcntl.flock(fd, LOCK_EX)` → 写入 PID
- `try_acquire()`: `fcntl.flock(fd, LOCK_EX | LOCK_NB)` → 成功返回 True，`BlockingIOError` 返回 False
- `release()`: `fcntl.flock(fd, LOCK_UN)` → 关闭 fd → 删除文件。**必须幂等**：重复调用不抛异常（信号处理器 + atexit + main 末尾可能调用 3 次，见 ralph_loop.py L74/L466/L608）
- `is_held_by_alive_process()`: 保留兼容性
- `__enter__`/`__exit__`: 使用 acquire/release

**Step 4: Run test — verify it passes**
Run: `python3 -m pytest tests/ralph-loop/test_lock.py -v`
Expected: PASS

**Step 5: Commit**
`git commit -am 'refactor: LockFile uses fcntl.flock for true mutual exclusion'`

---

### Task 2: 修复 WorktreeManager merge 脏状态问题

**Files:**
- Modify: `scripts/lib/worktree.py`
- Test: `tests/ralph-loop/test_worktree.py`

**Step 1: Write failing test**
新增 test_merge_failure_leaves_clean_state：制造冲突 → merge 失败 → 验证 git status --porcelain 为空。

**Step 2: Run test — verify it fails**
Run: `python3 -m pytest tests/ralph-loop/test_worktree.py::test_merge_failure_leaves_clean_state -v`
Expected: FAIL

**Step 3: Write minimal implementation**
修改 merge() except 块：删除无效的 `git merge --abort`，只保留 `git reset --hard HEAD`。

**Step 4: Run test — verify it passes**
Run: `python3 -m pytest tests/ralph-loop/test_worktree.py -v`
Expected: PASS

**Step 5: Commit**
`git commit -am 'fix: worktree merge uses reset --hard instead of merge --abort for squash'`

---

### Task 3: Git 操作重试机制

**Files:**
- Create: `scripts/lib/git_retry.py`
- Test: `tests/ralph-loop/test_git_retry.py`
- Modify: `scripts/lib/worktree.py`

**Step 1: Write failing test**
新增 test_git_run_succeeds_first_try, test_git_run_retries_on_lock, test_git_run_gives_up_after_max_retries, test_git_run_no_retry_on_non_lock_error。

**Step 2: Run test — verify it fails**
Run: `python3 -m pytest tests/ralph-loop/test_git_retry.py -v`
Expected: FAIL (模块不存在)

**Step 3: Write minimal implementation**
创建 git_retry.py：git_run() 函数，对 index.lock 等瞬时错误重试 3 次，指数退避。
修改以下位置的 git 调用改用 git_run：
- worktree.py 中 3 处 check=True 调用（L21 create, L29 merge --squash, L38 commit）
- ralph_loop.py L398-399 的 git add + git commit（run_parallel_batch 中 checklist 提交，AST 确认仅此 2 处）

**Step 4: Run test — verify it passes**
Run: `python3 -m pytest tests/ralph-loop/test_git_retry.py tests/ralph-loop/test_worktree.py -v`
Expected: PASS

**Step 5: Commit**
`git commit -am 'feat: git_retry module with exponential backoff for transient lock errors'`

---

### Task 4: verify 命令提取 fail-closed

**Files:**
- Modify: `scripts/ralph_loop.py`
- Test: `tests/ralph-loop/test_ralph_loop.py`

**Step 1: Write failing test**
新增 test_extract_verify_cmd_missing_returns_false, test_extract_verify_cmd_inline, test_extract_verify_cmd_fenced。

**Step 2: Run test — verify it fails**
Run: `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_extract_verify_cmd_missing_returns_false -v`
Expected: FAIL

**Step 3: Write minimal implementation**
修改 _extract_verify_cmd fallback 从 "echo 'no verify command found'" 改为 "false"。

**Step 4: Run test — verify it passes**
Run: `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_extract_verify_cmd_missing_returns_false tests/ralph-loop/test_ralph_loop.py::test_extract_verify_cmd_inline tests/ralph-loop/test_ralph_loop.py::test_extract_verify_cmd_fenced -v`
Expected: PASS

**Step 5: Commit**
`git commit -am 'fix: _extract_verify_cmd returns false instead of silent pass'`

---

### Task 5: 消除 build_batch_prompt 的 fake plan 对象

**Files:**
- Modify: `scripts/ralph_loop.py`
- Test: `tests/ralph-loop/test_ralph_loop.py`

**Step 1: Write failing test**
新增 test_build_batch_prompt_uses_real_plan：传入 PlanFile 实例，验证 prompt 包含正确的 progress_path 和 findings_path。

**Step 2: Run test — verify it fails**
Run: `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_build_batch_prompt_uses_real_plan -v`
Expected: FAIL

**Step 3: Write minimal implementation**
修改 build_batch_prompt 签名增加 plan: PlanFile = None。删除 type('_plan', (), {})() hack。
**同时更新调用处：** ralph_loop.py L547 build_batch_prompt(batches[0], plan_path, i) → 传入 plan 参数（AST 确认全局仅此 1 处调用）

**Step 4: Run test — verify it passes**
Run: `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_build_batch_prompt_uses_real_plan -v`
Expected: PASS

**Step 5: Commit**
`git commit -am 'refactor: build_batch_prompt accepts PlanFile, eliminates fake plan hack'`

---

### Task 6: 拆分 main() 为可测试阶段

**Files:**
- Modify: `scripts/ralph_loop.py`
- Test: `tests/ralph-loop/test_ralph_loop.py`

**Step 1: Write failing test**
新增 test_parse_config_defaults, test_parse_config_from_argv, test_validate_plan_missing。

**Step 2: Run test — verify it fails**
Run: `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_parse_config_defaults -v`
Expected: FAIL

**Step 3: Write minimal implementation**
从 main() 提取 parse_config(argv) -> Config dataclass 和 validate_plan(plan_path) -> PlanFile。main() 变为薄壳。

**Step 4: Run test — verify it passes**
Run: `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_parse_config_defaults tests/ralph-loop/test_ralph_loop.py::test_parse_config_from_argv tests/ralph-loop/test_ralph_loop.py::test_validate_plan_missing -v`
Expected: PASS

**Step 5: Commit**
`git commit -am 'refactor: extract parse_config, validate_plan from main()'`

---

### Task 7: cleanup_stale 安全性 — 检查活跃进程

**Files:**
- Modify: `scripts/lib/worktree.py`
- Modify: `scripts/ralph_loop.py`
- Test: `tests/ralph-loop/test_worktree.py`

**Step 1: Write failing test**
新增 test_cleanup_stale_preserves_active_worktrees：创建 worktree + .ralph-worker.lock（当前 PID）→ cleanup_stale → 验证 worktree 仍存在。

**Step 2: Run test — verify it fails**
Run: `python3 -m pytest tests/ralph-loop/test_worktree.py::test_cleanup_stale_preserves_active_worktrees -v`
Expected: FAIL

**Step 3: Write minimal implementation**
修改 cleanup_stale()：检查 .ralph-worker.lock，PID 存活则跳过。
修改 run_parallel_batch：创建 worktree 后写入 .ralph-worker.lock。

**Step 4: Run test — verify it passes**
Run: `python3 -m pytest tests/ralph-loop/test_worktree.py -v`
Expected: PASS

**Step 5: Commit**
`git commit -am 'fix: cleanup_stale checks for active worker locks before removing'`

---

### Task 8: 信号处理器线程安全 + cleanup handler 健壮性

**Files:**
- Modify: `scripts/ralph_loop.py`
- Test: `tests/ralph-loop/test_ralph_loop.py`

**Step 1: Write failing test**
新增 test_cleanup_handler_with_empty_procs 和 test_cleanup_handler_with_dead_pids。

**Step 2: Run test — verify it fails**
Run: `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_cleanup_handler_with_empty_procs tests/ralph-loop/test_ralph_loop.py::test_cleanup_handler_with_dead_pids -v`
Expected: 需验证

**Step 3: Write minimal implementation**
在 _cleanup_handler 中用 list(child_procs) 创建快照再遍历。

**顺带修复：** ralph_loop.py L328 open(log_path, "w") 未用 with 语句，Popen 失败时 fd 泄漏。改为 with 或 try/finally（AST 确认仅此 1 处裸 open）

**Step 4: Run test — verify it passes**
Run: `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_cleanup_handler_with_empty_procs tests/ralph-loop/test_ralph_loop.py::test_cleanup_handler_with_dead_pids -v`
Expected: PASS

**Step 5: Commit**
`git commit -am 'fix: cleanup handler uses list snapshots for thread safety'`

---

### Task 9: 集成测试 — flock 互斥 + 全量回归

**Files:**
- Test: `tests/ralph-loop/test_ralph_loop.py`

**Step 1: Write failing test**
新增 test_flock_prevents_double_ralph：启动第一个 ralph（sleep 60），启动第二个 → 验证第二个 exit 1 且输出包含 "lock" 或 "already running"。

**Step 2: Run test — verify it fails**
Run: `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_flock_prevents_double_ralph -v`
Expected: FAIL

**Step 3: Write minimal implementation**
修改 main() 中 lock.acquire() → try_acquire()，失败时 die("Another ralph-loop is already running")。

**Step 4: Run test — verify it passes**
Run: `python3 -m pytest tests/ralph-loop/ -v`
Expected: ALL PASS

**Step 5: Commit**
`git commit -am 'test: integration test for flock mutual exclusion + full regression'`

## Review
<!-- Reviewer writes here -->

## Checklist

- [x] LockFile 使用 fcntl.flock 实现真互斥 | `grep -q "fcntl.flock" scripts/lib/lock.py && python3 -c "from scripts.lib.lock import LockFile; print('ok')"`
- [x] try_acquire 方法存在且可调用 | `python3 -c "from scripts.lib.lock import LockFile; assert hasattr(LockFile, 'try_acquire'); print('ok')"`
- [x] 两个进程不能同时持有锁 | `python3 -m pytest tests/ralph-loop/test_lock.py::test_flock_mutual_exclusion -v`
- [x] worktree merge 失败后主分支干净 | `python3 -m pytest tests/ralph-loop/test_worktree.py::test_merge_failure_leaves_clean_state -v`
- [ ] git_retry 模块存在且可导入 | `python3 -c "from scripts.lib.git_retry import git_run; print('ok')"`
- [ ] git_retry 在 lock 错误时重试 | `python3 -m pytest tests/ralph-loop/test_git_retry.py::test_git_run_retries_on_lock -v`
- [ ] git_retry 超过最大重试次数后抛异常 | `python3 -m pytest tests/ralph-loop/test_git_retry.py::test_git_run_gives_up_after_max_retries -v`
- [ ] verify 命令缺失时返回 false（fail-closed） | `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_extract_verify_cmd_missing_returns_false -v`
- [ ] build_batch_prompt 接受 PlanFile 参数 | `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_build_batch_prompt_uses_real_plan -v`
- [ ] parse_config 函数存在且返回正确默认值 | `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_parse_config_defaults -v`
- [ ] validate_plan 对缺失文件抛 SystemExit | `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_validate_plan_missing -v`
- [x] cleanup_stale 保留活跃 worktree | `python3 -m pytest tests/ralph-loop/test_worktree.py::test_cleanup_stale_preserves_active_worktrees -v`
- [ ] cleanup handler 空列表不崩溃 | `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_cleanup_handler_with_empty_procs -v`
- [ ] 第二个 ralph 实例被锁阻止 | `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_flock_prevents_double_ralph -v`
- [ ] 回归测试通过 | `python3 -m pytest tests/ralph-loop/ -v`

## Errors

| Error | Task | Attempt | Resolution |
|-------|------|---------|------------|
