# Ralph Loop Parallel Worktree Execution

**Goal:** Make ralph_loop.py execute parallel batches via process-level parallelism with git worktree isolation, achieving ~4x speedup for independent tasks while preserving all existing reliability guarantees (circuit breaker, timeout, signal cleanup, lock guard).

**Non-Goals:** Not changing plan file format. Not changing scheduler algorithm (greedy is sufficient). Not implementing work-stealing (P3 future). Not changing hook architecture beyond the minimal env var check.

**Architecture:** Three-layer change: (1) `scripts/lib/worktree.py` — worktree lifecycle management (create/merge/cleanup), (2) `scripts/ralph_loop.py` — parallel batch execution via multiple subprocess.Popen with per-worker worktree isolation, selective merge, multi-worker signal cleanup, (3) `hooks/gate/enforce-ralph-loop.sh` — add `_RALPH_LOOP_RUNNING` env var check so workers in worktrees pass the gate. Sequential batches unchanged. Worker prompt is task-only (no plan updates, no progress writes). Ralph_loop.py handles all plan/progress/git coordination.

**Tech Stack:** Python 3, git worktree, pytest

## Review

Round 1 (4 reviewers parallel):
- Goal Alignment: APPROVE — all 8 tasks map to goal phrases, execution order valid
- Verify Correctness: REQUEST CHANGES — claimed verify commands test non-existent files. Rejected: this is TDD (verify runs after implementation). Weak import-only checks acceptable since stronger pytest checks also exist.
- Technical Feasibility: malformed (no verdict) — 3 findings all addressed by existing plan tasks. Rejected.
- Compatibility & Rollback: REQUEST CHANGES — Task 4 breaks existing `test_empty_file_sets`. **Accepted**: added note to Task 4 to update existing test.

Post-review fix: Task 4 description updated to include updating existing `test_empty_file_sets` assertion.

Round 2 (2 fixed angles, verifying fixes):
- Goal Alignment: APPROVE — coverage confirmed
- Verify Correctness: REQUEST CHANGES — verify #6 unsound (`echo hello` passes read-only allowlist regardless of env var). **Accepted**: changed to `grep -q '_RALPH_LOOP_RUNNING' hooks/gate/enforce-ralph-loop.sh` — currently returns exit 1 (string absent), will return exit 0 after implementation. Sound.

## Tasks

### Task 1: Worktree Lifecycle Manager

**Files:**
- Create: `scripts/lib/worktree.py`
- Test: `tests/ralph-loop/test_worktree.py`

**Verify:** `python3 -m pytest tests/ralph-loop/test_worktree.py -v`

**What to implement:**

`WorktreeManager` class with methods:
- `create(name)` → creates worktree at `.worktrees/ralph-{name}` on branch `ralph-worker-{name}`, returns Path
- `merge(name)` → `git merge --no-ff` worker branch into current branch. On conflict: abort + return False. On success: restore `docs/plans/` from pre-merge state (checkout HEAD~1 -- docs/plans/, amend commit), return True
- `remove(name)` → `git worktree remove --force` + `git branch -D`
- `cleanup_all()` → remove all tracked worktrees + prune
- `cleanup_stale()` → prune + remove any `ralph-*` dirs in base

Tests cover: create/cleanup, create multiple (4), stale cleanup, merge success (file appears in main), merge conflict (returns False), plan file restoration after merge (plan unchanged, code merged).

---

### Task 2: enforce-ralph-loop Env Var Bypass

**Files:**
- Modify: `hooks/gate/enforce-ralph-loop.sh`
- Test: `tests/ralph-loop/test-enforcement.sh`

**Verify:** `grep -q '_RALPH_LOOP_RUNNING' hooks/gate/enforce-ralph-loop.sh`

**What to implement:**

Add early exit after the `.skip-ralph` check: if `_RALPH_LOOP_RUNNING=1` env var is set, `exit 0`. This allows worker CLI processes (spawned by ralph_loop.py, which sets this env var) to pass the gate even when running in a worktree where `.ralph-loop.lock` doesn't exist.

Test: set env var, pipe a bash tool call, assert exit 0.

---

### Task 3: Worker Prompt Isolation

**Files:**
- Modify: `scripts/ralph_loop.py`
- Test: `tests/ralph-loop/test_ralph_loop.py`

**Verify:** `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_worker_prompt_no_plan_update -v`

**What to implement:**

Add `build_worker_prompt(task_name, task_files, verify_cmd, plan_path)` function. Returns a minimal prompt containing only: task name, file list, verify command, plan path for context reading. Explicitly says "Do NOT modify docs/plans/", "Do NOT run git commit". No checklist update instructions, no progress instructions.

Test: extract function from source, call it, assert no plan-update or progress keywords in output.

---

### Task 4: Empty File Set Fallback

**Files:**
- Modify: `scripts/lib/scheduler.py`
- Test: `tests/ralph-loop/test_scheduler.py`

**Verify:** `python3 -m pytest tests/ralph-loop/test_scheduler.py::test_empty_file_sets_sequential -v`

**What to implement:**

In `build_batches()`, if a task has empty `files` set, put it in its own sequential batch (don't try to parallelize with others). Also skip tasks with empty files when scanning for parallel candidates.

Test: 3 tasks with empty file sets → 3 sequential batches. Also update existing `test_empty_file_sets` to match new behavior (was: 1 parallel batch, now: 3 sequential batches).

---

### Task 5: Precheck Cache + Remove Sleep

**Files:**
- Modify: `scripts/ralph_loop.py`
- Test: `tests/ralph-loop/test_ralph_loop.py`

**Verify:** `! grep -q 'time\.sleep(2)' scripts/ralph_loop.py && grep -q 'prev_exit' scripts/ralph_loop.py`

**What to implement:**

1. Remove `time.sleep(2)` from main loop.
2. Track `prev_exit` (last iteration's CLI exit code). If `prev_exit == 0`, skip precheck and use cached "OK" status.

Test: assert `time.sleep(2)` not in source.

---

### Task 6: Heartbeat Stall Detection

**Files:**
- Modify: `scripts/ralph_loop.py`
- Test: `tests/ralph-loop/test_ralph_loop.py`

**Verify:** `grep -q 'STALL_TIMEOUT' scripts/ralph_loop.py`

**What to implement:**

Add `RALPH_STALL_TIMEOUT` env var (default 300s). In `_heartbeat()`, track `last_checked` count. If `plan.checked` hasn't increased for `STALL_TIMEOUT` seconds, kill the process via `os.killpg()`. This catches agents that are stuck without waiting for the full `TASK_TIMEOUT`.

Test: KIRO_CMD=sleep 60, TASK_TIMEOUT=30, STALL_TIMEOUT=4, HEARTBEAT_INTERVAL=1 → process killed in <15s.

---

### Task 7: Parallel Batch Execution in ralph_loop.py

**Files:**
- Modify: `scripts/ralph_loop.py`
- Test: `tests/ralph-loop/test_ralph_loop.py`

**Verify:** `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_parallel_batch_creates_worktrees -v`

**What to implement:**

Modify main loop: when `current_batch.parallel`:
1. Create N worktrees via WorktreeManager
2. Spawn N CLI processes (cwd=worktree, log to `.ralph-logs/worker-{name}.log`)
3. Wait all with per-worker timeout
4. For each successful worker: merge, restore plan
5. Update plan checklist + write progress for batch
6. Single git commit for batch results
7. Cleanup worktrees

Update `_cleanup_handler`: track `_child_procs` list, kill all on signal, cleanup worktrees.
On startup: `wt_manager.cleanup_stale()` to remove orphans.

Test: plan with 2 independent tasks + marker script → stdout contains "parallel" or "worktree".

---

### Task 8: Regression

**Files:**
- Test: `tests/ralph-loop/test_ralph_loop.py`
- Test: `tests/ralph-loop/test_scheduler.py`
- Test: `tests/ralph-loop/test_worktree.py`
- Test: `tests/ralph-loop/test_plan.py`
- Test: `tests/ralph-loop/test_precheck.py`
- Test: `tests/ralph-loop/test_lock.py`

**Verify:** `python3 -m pytest tests/ralph-loop/ -v`

Run full regression. Fix any tests broken by changes. Expected: All pass.

---

## Findings
<!-- Append-only during execution -->
- Industry consensus: worktree per agent is standard pattern (Anthropic Swarm, incident.io, mldangelo 1000+ PRs)
- Merge strategy: --no-ff preferred over cherry-pick/rebase for traceability
- Git object store is concurrent-safe (atomic renames + locking)
- Worker prompt must be task-only — no plan/progress/commit instructions
- enforce-ralph-loop.sh needs env var bypass for worktree workers (lock file is path-relative)
- Empty file set tasks must not be parallelized (unknown implicit deps)
- Worker logs must be outside worktree (cleanup deletes worktree)
- Precheck: skip within batch, re-run between batches after merge

## Errors

| Error | Task | Attempt | Resolution |
|-------|------|---------|------------|

## Checklist

- [x] WorktreeManager.create 创建 worktree + 分支 | `python3 -c "from scripts.lib.worktree import WorktreeManager; print('import ok')"`
- [x] WorktreeManager.merge 合并 worker 分支 | `python3 -m pytest tests/ralph-loop/test_worktree.py::test_merge_success -v`
- [x] WorktreeManager.merge 冲突返回 False | `python3 -m pytest tests/ralph-loop/test_worktree.py::test_merge_conflict_returns_false -v`
- [x] Merge 后 plan 文件恢复 | `python3 -m pytest tests/ralph-loop/test_worktree.py::test_restore_plan_after_merge -v`
- [x] WorktreeManager.cleanup_all 清理所有 worktree | `python3 -m pytest tests/ralph-loop/test_worktree.py::test_create_multiple -v`
- [x] enforce-ralph-loop 环境变量放行 | `grep -q '_RALPH_LOOP_RUNNING' hooks/gate/enforce-ralph-loop.sh`
- [x] build_worker_prompt 不含 plan 更新指令 | `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_worker_prompt_no_plan_update -v`
- [x] 空文件集 task 不并行 | `python3 -m pytest tests/ralph-loop/test_scheduler.py::test_empty_file_sets_sequential -v`
- [ ] time.sleep(2) 已移除 | `! grep -q 'time\.sleep(2)' scripts/ralph_loop.py`
- [ ] precheck 缓存（上次成功跳过） | `grep -q 'prev_exit' scripts/ralph_loop.py`
- [ ] Stall 检测提前终止 | `grep -q 'STALL_TIMEOUT' scripts/ralph_loop.py`
- [ ] 并行 batch 创建 worktree 并行执行 | `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_parallel_batch_creates_worktrees -v`
- [ ] 回归测试通过 | `python3 -m pytest tests/ralph-loop/ -v`
