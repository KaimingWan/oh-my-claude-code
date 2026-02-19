# Ralph Parallel Worktree — Progress Log

## Dispatch — 2026-02-19 13:53
- **Mode:** Parallel fan-out (Strategy D)
- **Batch:** Tasks 1-4 dispatched to 4 executor subagents
- **Tasks:**
  - T1: Worktree Lifecycle Manager → executor
  - T2: enforce-ralph-loop Env Var Bypass → executor
  - T3: Worker Prompt Isolation → executor
  - T4: Empty File Set Fallback → executor
- **Status:** dispatched

## Batch 1 Results — 2026-02-19 13:55

### T1: Worktree Lifecycle Manager ✅
- **Files created:** scripts/lib/worktree.py, tests/ralph-loop/test_worktree.py
- **Tests:** 6/6 passed (create_and_cleanup, create_multiple, stale_cleanup, merge_success, merge_conflict, plan_restoration_after_merge)
- **Verify:** `python3 -m pytest tests/ralph-loop/test_worktree.py -v` → PASS

### T2: enforce-ralph-loop Env Var Bypass ✅
- **Files modified:** hooks/gate/enforce-ralph-loop.sh, tests/ralph-loop/test-enforcement.sh
- **Change:** Added `_RALPH_LOOP_RUNNING=1` early exit after .skip-ralph check
- **Fix:** Also added `unset _RALPH_LOOP_RUNNING` in test setup() to prevent env leak from parent ralph loop
- **Verify:** `grep -q '_RALPH_LOOP_RUNNING' hooks/gate/enforce-ralph-loop.sh` → PASS
- **Enforcement tests:** 21/21 passed

### T3: Worker Prompt Isolation ✅
- **Files modified:** scripts/ralph_loop.py, tests/ralph-loop/test_ralph_loop.py
- **Change:** Added `build_worker_prompt()` function with task-only prompt, no plan/progress instructions
- **Verify:** `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_worker_prompt_no_plan_update -v` → PASS

### T4: Empty File Set Fallback ✅
- **Files modified:** scripts/lib/scheduler.py, tests/ralph-loop/test_scheduler.py
- **Change:** Empty-files tasks get individual sequential batches, not parallelized
- **Verify:** `python3 -m pytest tests/ralph-loop/test_scheduler.py::test_empty_file_sets_sequential -v` → PASS

### Regression
- **Full suite:** 98/98 passed in 87s
- **Enforcement:** 21/21 passed
- **Status:** All clean, no regressions

## Iteration 2 — 2026-02-19
- **Task:** Tasks 5-8: Precheck cache, Stall detection, Parallel batch execution, Regression
- **Files changed:**
  - `scripts/ralph_loop.py` — removed time.sleep(2), added prev_exit precheck cache, STALL_TIMEOUT stall detection in heartbeat, WorktreeManager import, run_parallel_batch() function, parallel batch routing in main loop, _child_procs list, startup cleanup_stale()
  - `tests/ralph-loop/test_ralph_loop.py` — added test_parallel_batch_creates_worktrees, test_sleep_removed_from_source, test_prev_exit_in_source, test_stall_timeout_in_source, test_stall_detection_kills_process; fixed test_lock_cleanup_on_signal and test_sigint_cleanup (pre-existing failure: macOS sleep rejects extra args)
- **Learnings:**
  - macOS `sleep N <extra-args>` exits with code 1 (GNU sleep ignores extras). Tests using `RALPH_KIRO_CMD=sleep 60` via Popen (where prompt is appended as arg) were silently failing — use shell script wrapper instead
  - `_RALPH_LOOP_RUNNING=1` is set in the parent environment when running inside a ralph loop; subprocess.Popen with explicit env dict correctly excludes it
  - stall detection in heartbeat: track last_checked, accumulate stall_elapsed, kill on STALL_TIMEOUT
  - Parallel batch routing: when `batch.parallel=True`, call run_parallel_batch() instead of building a prompt; sequential batches use the existing single-CLI path
  - Worker log dir (.ralph-logs) must be outside worktree (worktree cleanup deletes the worktree dir)
- **Status:** done — 103/103 passed
