# ~~Fix Ralph Loop Parallel Execution Bugs~~ (OBSOLETE)

> **⚠️ OBSOLETE** — 废弃于 2026-02-21。原因：plan 创建后 ralph_loop.py/plan.py/worktree.py 累计改动 338 行，行号引用和函数签名全部过时。Bug 描述仍有效，需基于当前代码重新规划。


**Goal:** Fix six bugs in ralph_loop.py parallel worktree execution: (1) orphan worker processes surviving after ralph exits, (2) unchecked_tasks() returning completed tasks when task:checklist ratio is not 1:1, (3) worker prompt lacking checklist state causing wasted iterations, (4) no rate-limit awareness causing all workers to fail simultaneously, (5) verify_and_check_all() writes to plan file but doesn't git commit, so subsequent merges overwrite the checked-off items, (6) --no-ff merge creates noisy merge commits polluting git history.
**Non-Goals:** Rewrite sequential execution path; add new parallel strategies; change scheduler algorithm.
**Architecture:** All fixes are in ralph_loop.py, plan.py, and worktree.py. Task 1 fixes orphan cleanup. Task 2 fixes unchecked_tasks() for N:M mapping. Task 3 adds checklist context to worker prompt. Task 4 adds worker count throttling. Task 5 fixes checklist persistence after parallel merges. Task 6 switches to squash merge for clean history.
**Tech Stack:** Python 3, pytest, git

## Tasks

### Task 1: Fix orphan worker process cleanup

**Files:**
- Modify: `scripts/ralph_loop.py`
- Test: `tests/ralph-loop/test_ralph_loop.py`

**Step 1: Write failing test**
`test_parallel_workers_killed_on_exit`: Start ralph with a plan that triggers parallel mode (2 independent tasks), KIRO_CMD=sleep 5 (short timeout to keep test fast), RALPH_TASK_TIMEOUT=3, max_iter=1. After ralph exits, verify no child processes with the unique name remain. Current code may leave orphans because `child_procs` list is mutated during `run_parallel_batch` cleanup. Use `pgrep -f unique_name` for detection (macOS compatible, no /proc needed).

**Step 2: Fix ralph_loop.py**
In `run_parallel_batch()`, the bug is in the child_procs cleanup line:
```python
child_procs[:] = [p for p in child_procs if p not in finished_procs or p.poll() is None]
```
This keeps processes that are "not finished OR still alive" — but after `proc.wait()` they ARE finished, so `p not in finished_procs` is False, and `p.poll() is None` is also False (they exited). So they get removed. The real problem: if ralph gets SIGTERM during the merge phase (after workers finished and child_procs was cleaned), the cleanup handler has nothing to kill. But the workers spawned with `start_new_session=True` may have child processes of their own (kiro-cli spawns subprocesses).

Fix: track worker PIDs in a separate `_worker_pids` set that is NOT cleared until worktree removal. In `make_cleanup_handler`, iterate `_worker_pids` and kill each process group via `os.killpg(os.getpgid(pid))` — this is safe because workers use `start_new_session=True` so each has its own process group. Validate PID is still alive and belongs to the expected process group before killing (check `os.getpgid(pid)` matches the stored pgid). Do NOT use `pkill -P` (PID reuse risk).

**Step 3: Run test**
Run: `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_parallel_workers_killed_on_exit -v`
Expected: PASS

**Step 4: Commit**
`fix: ralph_loop — track worker PIDs for orphan-proof cleanup`

**Verify:** `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_parallel_workers_killed_on_exit -v`

---

### Task 2: Fix unchecked_tasks() for N:M task:checklist mapping

**Files:**
- Modify: `scripts/lib/plan.py`
- Test: `tests/ralph-loop/test_plan.py`

**Step 1: Write failing test**
`test_unchecked_tasks_many_to_many`: Plan with 6 tasks and 13 checklist items (like the hardening sprint). Check off 11 items. `unchecked_tasks()` should return only the tasks whose checklist items are still unchecked — NOT all 6 tasks.

`test_unchecked_tasks_no_match_fallback`: Plan with tasks whose names don't match any checklist item text. Should fall back to returning all tasks (safe behavior).

Strategy: instead of positional 1:1 mapping, match tasks to checklist items by keyword/description overlap. Each checklist item's text is compared against task names. A task is "done" if ALL its matched checklist items are checked. Use longest-match-first to disambiguate similar names (e.g. "Fix parser tests" matches before "Fix parser").

**Step 2: Fix plan.py**
Replace the fallback `return tasks` in `unchecked_tasks()` with a keyword-matching approach:
1. For each checklist item, find which task it belongs to by matching task name keywords against item text
2. Group checklist items by task
3. A task is unchecked if ANY of its matched items is `- [ ]`
4. If a checklist item can't be matched to any task, treat it as belonging to a virtual "unmatched" group — if any unmatched items are unchecked, return all tasks (safe fallback)

**Step 3: Run test**
Run: `python3 -m pytest tests/ralph-loop/test_plan.py -v`
Expected: PASS

**Step 4: Commit**
`fix: unchecked_tasks() — keyword matching for N:M task:checklist mapping`

**Verify:** `python3 -m pytest tests/ralph-loop/test_plan.py::test_unchecked_tasks_many_to_many -v`

---

### Task 3: Add checklist state to worker prompt

**Files:**
- Modify: `scripts/ralph_loop.py`
- Test: `tests/ralph-loop/test_ralph_loop.py`

**Step 1: Write failing test**
`test_worker_prompt_includes_checklist_state`: Call `build_worker_prompt()` with checklist_context param containing actual checklist lines (mix of `[x]` and `[ ]`). Verify the prompt contains the specific unchecked item text (not just static keywords like "remaining"), so the worker knows exactly which items to work on.

**Step 2: Fix ralph_loop.py**
Add optional `checklist_context` parameter to `build_worker_prompt()`. In `run_parallel_batch()`, pass the current checklist state (which items are `[x]` vs `[ ]`) so the worker can skip already-done work. Format: a short summary like "Completed: 11/13. Your task items: - [ ] item A, - [ ] item B".

**Step 3: Run test**
Run: `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_worker_prompt_includes_checklist_state -v`
Expected: PASS

**Step 4: Commit**
`fix: worker prompt — include checklist state to prevent wasted iterations`

**Verify:** `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_worker_prompt_includes_checklist_state -v`

---

### Task 4: Rate-limit aware worker throttling

**Files:**
- Modify: `scripts/ralph_loop.py`
- Test: `tests/ralph-loop/test_ralph_loop.py`

**Step 1: Write failing test**
`test_max_parallel_workers_env`: Set `RALPH_MAX_PARALLEL_WORKERS=2`, create plan with 4 independent tasks. Verify ralph only spawns 2 workers per batch (not 4).

**Step 2: Fix ralph_loop.py**
Add `RALPH_MAX_PARALLEL_WORKERS` env var (default: 4, matching use_subagent hard limit). In `run_parallel_batch()`, if batch has more tasks than max_workers, split into sub-batches and run sequentially. Also: when a worker fails with exit code 1 and its log contains "rate limit" or "hit your limit" (checked via first 1KB of log, no further parsing — just substring match), print a warning and reduce max_workers by 1 for subsequent batches in this iteration.

**Step 3: Run test**
Run: `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_max_parallel_workers_env -v`
Expected: PASS

**Step 4: Commit**
`fix: ralph_loop — rate-limit aware worker throttling`

**Verify:** `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_max_parallel_workers_env -v`

---

### Task 5: Fix checklist persistence after parallel merges

**Files:**
- Modify: `scripts/ralph_loop.py`
- Modify: `scripts/lib/worktree.py`
- Test: `tests/ralph-loop/test_ralph_loop.py`

**Step 1: Write failing test**
`test_parallel_checklist_persists_after_merge`: Create a plan with 2 independent tasks, each with 1 checklist item with a verify command that always passes (`echo ok`). Run ralph with KIRO_CMD that creates a file in the worktree (simulating real work). After ralph completes, read the plan file and verify checklist items are `[x]`, not `[ ]`.

**Step 2: Root cause analysis**
The bug chain:
1. `run_parallel_batch()` merges workers one by one: `wt_manager.merge(name)`
2. Each `merge()` does `git merge --no-ff` then `git checkout HEAD~1 -- docs/plans/` to restore plan from pre-merge state (protecting plan from worker modifications)
3. After ALL merges, `verify_and_check_all()` writes `[x]` to the plan file on disk
4. But this write is NOT committed to git
5. Next iteration: `plan.reload()` reads from disk (OK so far)
6. But if there's another merge in the next iteration, `git checkout HEAD~1 -- docs/plans/` overwrites the disk file, reverting `[x]` back to `[ ]`

**Step 3: Fix**
In `run_parallel_batch()`, after `verify_and_check_all()` succeeds and checks off items, commit the plan file:
```python
if succeeded:
    plan.reload()
    results = plan.verify_and_check_all(cwd=str(project_root))
    # ... print results ...
    checked_count = sum(1 for _, _, p in results if p)
    if checked_count > 0:
        subprocess.run(["git", "add", str(plan.path)], cwd=str(project_root))
        subprocess.run(["git", "commit", "-m", f"ralph: check off {checked_count} items"],
                       cwd=str(project_root), check=True)
```

Also need to handle the edge case: if `verify_and_check_all` is called but the plan file is in a dirty git state from a previous failed commit, `git add` + `git commit` should still work.

**Step 4: Run test**
Run: `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_parallel_checklist_persists_after_merge -v`
Expected: PASS

**Step 5: Commit**
`fix: ralph_loop — git commit checklist after verify_and_check_all in parallel mode`

**Verify:** `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_parallel_checklist_persists_after_merge -v`

---

### Task 6: Switch to squash merge for clean history

**Files:**
- Modify: `scripts/lib/worktree.py`
- Test: `tests/ralph-loop/test_worktree.py`

**Step 1: Write failing test**
`test_squash_merge_no_merge_commit`: Create worktree, add a file, commit in worktree. Call `merge()`. Verify the resulting commit on main is NOT a merge commit (`git cat-file -p HEAD` should show only one `parent` line, not two).

**Step 2: Fix worktree.py**
Change `merge()` from `git merge --no-ff` to `git merge --squash` + `git commit`. Squash merge stages all changes but doesn't commit, so we follow with `git commit -m "feat: <task_name>"`. Update method signature to accept `task_name` parameter for the commit message.

The docs/plans/ restoration logic can be simplified: `--squash` doesn't create a merge commit, so `HEAD~1` is the pre-merge state. But since squash stages changes without committing, we can check staged files before committing and unstage docs/plans/ if present:
```python
subprocess.run(["git", "merge", "--squash", branch_name], check=True, cwd=...)
# Unstage docs/plans/ if staged
subprocess.run(["git", "reset", "HEAD", "--", "docs/plans/"], cwd=..., capture_output=True)
subprocess.run(["git", "checkout", "--", "docs/plans/"], cwd=..., capture_output=True)
subprocess.run(["git", "commit", "-m", f"feat: {task_name}"], check=True, cwd=...)
```

**Step 3: Update callers**
In `run_parallel_batch()`, pass `task.name` to `wt_manager.merge(name, task_name=task.name)`.

**Step 4: Run test**
Run: `python3 -m pytest tests/ralph-loop/test_worktree.py -v`
Expected: PASS

**Step 5: Commit**
`fix: worktree merge — switch to squash merge for clean history`

**Verify:** `python3 -m pytest tests/ralph-loop/test_worktree.py::test_squash_merge_no_merge_commit -v`

---

## Review

### Round 1 (4 reviewers)
- **Goal Alignment:** APPROVE — all 4 tasks map 1:1 to goal phrases, tasks are independent. Note: keyword disambiguation for similar task names → addressed by adding longest-match-first strategy.
- **Verify Correctness:** REQUEST CHANGES — valid: sleep 60 in test too long for CI. **Fixed:** reduced to sleep 5 + TASK_TIMEOUT=3.
- **Testability:** REQUEST CHANGES — valid: Task 3 test too static (keywords vs content), Task 1 macOS /proc issue, Task 2 missing zero-match edge case. **Fixed:** all three addressed.
- **Security:** REQUEST CHANGES — valid: pkill PID reuse risk, log injection. **Fixed:** replaced pkill with process group validation via os.killpg + stored pgid; log reading limited to 1KB substring match.

### Round 2 (2 reviewers — fixed angles only)
- **Goal Alignment:** REQUEST CHANGES — reviewer checked if implementation exists in source code. **Rejected finding:** this is a plan review, not implementation review. Tests and code are created during @execute phase. Plan structure and coverage are correct.
- **Verify Correctness:** REQUEST CHANGES — same issue: reviewer ran verify commands against current (pre-implementation) code. **Rejected finding:** verify commands validate post-implementation state. All 5 commands are structurally sound.

### Post-review addition: Task 5 & Task 6
Task 5 added after discovering checklist persistence bug during hardening sprint execution. Root cause traced through git history (13 merge commits all showing 0 `[x]` items). This is the highest-priority fix — without it, parallel mode's circuit breaker always triggers because `plan.checked` never increases.

Task 6 added after analyzing commit history pollution: 28 commits for a 6-task plan, 16 of which are merge commits (57%). Root cause: Bug 2 (repeated task dispatch) × `--no-ff` merge = redundant merge commits. Fix: squash merge produces one clean commit per worker.

**Final verdict: APPROVE (Round 1 substantive issues fixed; Round 2 rejections are procedural; Task 5 added with full root cause analysis)**

## Checklist
- [ ] 孤儿进程清理：worker PID 跟踪 + cleanup handler 覆盖 | `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_parallel_workers_killed_on_exit -v`
- [ ] unchecked_tasks N:M 映射正确 | `python3 -m pytest tests/ralph-loop/test_plan.py::test_unchecked_tasks_many_to_many -v`
- [ ] worker prompt 包含 checklist 状态 | `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_worker_prompt_includes_checklist_state -v`
- [ ] 并行 worker 数量可配置 | `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_max_parallel_workers_env -v`
- [ ] checklist 勾选在 merge 后持久化 | `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_parallel_checklist_persists_after_merge -v`
- [ ] squash merge 无 merge commit | `python3 -m pytest tests/ralph-loop/test_worktree.py::test_squash_merge_no_merge_commit -v`
- [ ] 回归测试通过 | `python3 -m pytest tests/ralph-loop/ -v`

## Errors

| Error | Task | Attempt | Resolution |
|-------|------|---------|------------|
