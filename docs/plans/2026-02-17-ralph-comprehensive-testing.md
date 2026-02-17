# Ralph Loop Comprehensive Testing

**Goal:** Add thorough tests for Ralph Loop covering concurrency (batch scheduling, task dispatch, process-level lock contention), accuracy (checklist tracking edge cases, positional mapping, prompt content correctness), and stability (signal handling, fault tolerance, resource leaks, external interference recovery).
**Non-Goals:** Not changing Ralph's runtime behavior or fixing bugs (test-only). Not testing kiro-cli itself. Not testing enforce-ralph-loop.sh (already has shell tests). Not adding CI pipeline configuration.
**Architecture:** All new tests in `tests/ralph-loop/` as pytest. Slow tests marked `@pytest.mark.slow`. No live kiro-cli dependency — use `RALPH_KIRO_CMD` env for process-level tests, direct function calls for unit tests. Add `conftest.py` with shared fixtures.
**Tech Stack:** Python 3.10+, pytest, threading (for race condition tests), textwrap, subprocess, tempfile

## Review

### Round 1 (Goal Alignment / Verify Correctness / Performance / Completeness)
- **Goal Alignment**: APPROVE ✅ — All 14 tasks map to stated Goal. No missing tasks, no unnecessary tasks. Execution trace from Task 1→14 reaches Goal.
- **Verify Correctness**: REQUEST CHANGES — 1 finding: checklist item 1 verify command had false positive (`echo "exit:$?"` always exits 0). **Fixed:** replaced with `assert Path(...).exists() && pytest --co`.
- **Performance**: APPROVE ✅ — Estimated 30-75s for process-level tests. Timing-dependent tests have conservative timeouts. No N+1 or expensive loops.
- **Completeness**: APPROVE ✅ — 3 minor nits (heartbeat output format, env var validation, summary write permissions). All assessed as non-core edge cases outside Goal scope. No action needed.

## Tasks

### Task 1: Shared test fixtures — conftest.py

**Files:**
- Create: `tests/ralph-loop/conftest.py`
- Test: `tests/ralph-loop/conftest.py`

**Verify:** `python3 -c "from pathlib import Path; assert Path('tests/ralph-loop/conftest.py').exists()" && python3 -m pytest tests/ralph-loop/ --co -q`

**What to implement:**

Create `tests/ralph-loop/conftest.py` with shared fixtures:
- `plan_factory(tmp_path)`: factory fixture that generates plan files with configurable task count, checked/unchecked/skip pattern, and file sets. Returns `(plan_path, active_path)`.
- `ralph_env(tmp_path)`: returns base env dict for `run_ralph` calls (PATH, HOME, PLAN_POINTER_OVERRIDE, RALPH_SKIP_DIRTY_CHECK, etc.)
- `import_ralph_fn(fn_name)`: helper to extract a function from `ralph_loop.py` without executing module-level code (refactored from existing `_import_build_batch_prompt` pattern)

---

### Task 2: Scheduler parametric tests — equivalence class coverage

**Files:**
- Modify: `tests/ralph-loop/test_scheduler.py`
- Test: `tests/ralph-loop/test_scheduler.py`

**Verify:** `python3 -m pytest tests/ralph-loop/test_scheduler.py -v`

**What to implement:**

Add parametrized tests covering the `(task_count, overlap_pattern, max_parallel)` input space:

- `test_batch_grouping_parametric`: parametrize over:
  - (1 task, no overlap, max=4) → 1 sequential batch
  - (4 tasks, no overlap, max=4) → 1 parallel batch of 4
  - (5 tasks, no overlap, max=4) → 2 batches (4+1)
  - (4 tasks, all share same file, max=4) → 4 sequential batches
  - (4 tasks, 2 pairs sharing files, max=4) → 2 parallel batches of 2
  - (8 tasks, no overlap, max=2) → 4 parallel batches of 2
  - (4 tasks, chain overlap A↔B↔C↔D where each shares with neighbor only, max=4) → 2 parallel batches (greedy: A+C then B+D, since non-adjacent tasks have no direct overlap)
- `test_batch_stability`: same input produces same output on repeated calls (determinism)
- `test_large_task_set`: 50 independent tasks, max_parallel=4 → all batches ≤4, total tasks preserved
- `test_empty_file_sets`: tasks with empty file sets are independent of everything

---

### Task 3: Checklist accuracy edge cases

**Files:**
- Modify: `tests/ralph-loop/test_plan.py`
- Test: `tests/ralph-loop/test_plan.py`

**Verify:** `python3 -m pytest tests/ralph-loop/test_plan.py -v`

**What to implement:**

Add tests for checklist parsing edge cases:

- `test_counts_with_extra_whitespace`: checklist items with leading spaces (e.g. indented items) are NOT counted by regex (regex requires line-start `^`). Verify that only properly formatted items are counted.
- `test_counts_mixed_skip_states`: plan with checked, unchecked, and SKIP items → each counter correct
- `test_reload_after_external_modify`: write plan, create PlanFile, externally overwrite plan with different state, reload → counts reflect new state
- `test_task_count_mismatch_more_checklist`: 3 tasks but 5 checklist items → `unchecked_tasks()` returns only tasks with matching unchecked items (extras ignored)
- `test_task_count_mismatch_fewer_checklist`: 5 tasks but 3 checklist items → tasks 4,5 treated as unchecked
- `test_checklist_with_skip_positional`: plan with `[x], [SKIP], [ ], [ ]` → unchecked_tasks returns tasks 3 and 4 (SKIP occupies position)
- `test_parse_tasks_malformed_header`: task header missing number or colon → gracefully skipped, other tasks still parsed

---

### Task 4: Prompt content structural correctness

**Files:**
- Modify: `tests/ralph-loop/test_ralph_loop.py`
- Test: `tests/ralph-loop/test_ralph_loop.py`

**Verify:** `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_parallel_prompt_structure tests/ralph-loop/test_ralph_loop.py::test_sequential_prompt_structure tests/ralph-loop/test_ralph_loop.py::test_prompt_iteration_number tests/ralph-loop/test_ralph_loop.py::test_prompt_file_paths -v`

**What to implement:**

Upgrade prompt tests from keyword-existence to structural contract assertions:

- `test_parallel_prompt_structure`: parallel batch with 3 tasks → prompt contains each task's number, name, AND at least one file path per task
- `test_sequential_prompt_structure`: sequential batch → prompt contains the single task's number, name, and file paths
- `test_prompt_iteration_number`: iteration=7 → prompt contains "7" in iteration context
- `test_prompt_file_paths`: batch with tasks having specific files → every file path appears in prompt

---

### Task 5: Batch recomputation after partial completion

**Files:**
- Modify: `tests/ralph-loop/test_scheduler.py`
- Modify: `tests/ralph-loop/test_plan.py`
- Test: `tests/ralph-loop/test_plan.py`

**Verify:** `python3 -m pytest tests/ralph-loop/test_plan.py::test_recompute_after_partial_completion tests/ralph-loop/test_scheduler.py::test_rebatch_after_removal -v`

**What to implement:**

- `test_recompute_after_partial_completion` (in test_plan.py): plan with 4 tasks (T1+T2 parallel, T3 depends on T1). Check off T1 → `unchecked_tasks()` returns T2, T3, T4. Feed to `build_batches()` → T3 no longer blocked by T1, verify new batch structure is correct.
- `test_rebatch_after_removal` (in test_scheduler.py): build_batches with 4 tasks → remove completed tasks → rebuild → verify batch structure changes correctly (e.g., previously blocked task now in parallel batch).

---

### Task 6: Summary output verification

**Files:**
- Modify: `tests/ralph-loop/test_ralph_loop.py`
- Test: `tests/ralph-loop/test_ralph_loop.py`

**Verify:** `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_summary_success tests/ralph-loop/test_ralph_loop.py::test_summary_failure -v`

**What to implement:**

- `test_summary_success`: run ralph with all-checked plan → `.ralph-result` contains "SUCCESS", correct checked/remaining counts, plan path
- `test_summary_failure`: run ralph with unchecked plan + `RALPH_KIRO_CMD=true` + max_iter=1 → `.ralph-result` contains "FAILED", lists remaining items

---

### Task 7: Process-level lock contention

**Files:**
- Modify: `tests/ralph-loop/test_lock.py`
- Modify: `tests/ralph-loop/test_ralph_loop.py`
- Test: `tests/ralph-loop/test_ralph_loop.py`

**Verify:** `python3 -m pytest tests/ralph-loop/test_lock.py::test_concurrent_acquire tests/ralph-loop/test_ralph_loop.py::test_double_ralph_no_lock_guard -v`

**What to implement:**

- `test_concurrent_acquire` (in test_lock.py): spawn 2 threads both calling `acquire()` on same lock path → both write, last writer wins (no crash, no corruption)
- `test_double_ralph_no_lock_guard` (in test_ralph_loop.py): start ralph as background process (sleep 60 as KIRO_CMD), then start second ralph with same plan → second instance overwrites lock and also runs (ralph has NO lock contention check — `acquire()` is unconditional `write_text`). Both exit without crash. This documents current behavior as a regression test.

---

### Task 8: Signal handling and cleanup

**Files:**
- Modify: `tests/ralph-loop/test_ralph_loop.py`
- Test: `tests/ralph-loop/test_ralph_loop.py`

**Verify:** `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_sigint_cleanup tests/ralph-loop/test_ralph_loop.py::test_child_process_no_orphan -v`

**What to implement:**

- `test_sigint_cleanup`: start ralph (KIRO_CMD=sleep 60), send SIGINT → lock file cleaned up, process exits
- `test_child_process_no_orphan`: start ralph with a KIRO_CMD that runs a uniquely-named script (e.g. `ralph_test_orphan_<pid>.sh` containing `sleep 60`), timeout=2 → after timeout kill, verify no process with that unique name remains (use `pgrep -f` with the unique name). This avoids false matches from unrelated `sleep` processes.

---

### Task 9: Fault tolerance — corrupted/abnormal inputs

**Files:**
- Modify: `tests/ralph-loop/test_plan.py`
- Modify: `tests/ralph-loop/test_ralph_loop.py`
- Test: `tests/ralph-loop/test_ralph_loop.py`

**Verify:** `python3 -m pytest tests/ralph-loop/test_plan.py::test_truncated_plan tests/ralph-loop/test_plan.py::test_binary_content_in_plan tests/ralph-loop/test_ralph_loop.py::test_active_points_to_missing_file tests/ralph-loop/test_ralph_loop.py::test_empty_active_file -v`

**What to implement:**

- `test_truncated_plan` (test_plan.py): plan file cut off mid-checklist → PlanFile parses what it can, no crash
- `test_binary_content_in_plan` (test_plan.py): plan with non-UTF-8 bytes → `PlanFile.__init__` raises `UnicodeDecodeError` from `path.read_text()`. Test should verify the exception type (we do NOT change runtime code per Non-Goals).
- `test_active_points_to_missing_file` (test_ralph_loop.py): .active contains path to non-existent file → ralph exits with clear error
- `test_empty_active_file` (test_ralph_loop.py): .active is empty string → `Path('')` resolves to current directory → ralph crashes with `IsADirectoryError` (unhandled). Test verifies `returncode != 0`.

---

### Task 10: External interference recovery

**Files:**
- Modify: `tests/ralph-loop/test_ralph_loop.py`
- Test: `tests/ralph-loop/test_ralph_loop.py`

**Verify:** `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_plan_modified_during_iteration tests/ralph-loop/test_ralph_loop.py::test_lock_deleted_during_run -v`

**What to implement:**

- `test_plan_modified_during_iteration`: start ralph, use a KIRO_CMD script that modifies the plan (checks off an item) then exits → ralph should detect progress on next reload, not stale-count it
- `test_lock_deleted_during_run`: start ralph (KIRO_CMD=sleep 2), delete lock file while running → ralph should still complete iteration (lock deletion doesn't crash it)

---

### Task 11: Concurrent plan file access (threading race condition)

**Files:**
- Modify: `tests/ralph-loop/test_plan.py`
- Test: `tests/ralph-loop/test_plan.py`

**Verify:** `python3 -m pytest tests/ralph-loop/test_plan.py::test_concurrent_reload -v`

**What to implement:**

- `test_concurrent_reload`: create PlanFile, spawn 10 threads each calling `reload()` + reading `checked`/`unchecked` simultaneously while another thread writes to the plan file → no crash, no exception, no negative values. Do NOT assert `checked + unchecked == total` — the three property accesses are not atomic (each does an independent regex scan on `_text`, which may be replaced between calls by another thread's `reload()`).

---

### Task 12: Long-running stability (slow tests)

**Files:**
- Modify: `tests/ralph-loop/test_ralph_loop.py`
- Test: `tests/ralph-loop/test_ralph_loop.py`

**Verify:** `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_many_iterations_no_hang tests/ralph-loop/test_ralph_loop.py::test_heartbeat_thread_cleanup -v`

**What to implement:**

Mark with `@pytest.mark.slow`:

- `test_many_iterations_no_hang`: run ralph with 10 iterations (KIRO_CMD=true, plan never completes) → ralph exits within reasonable time (no hang from leaked threads or unclosed resources). Verify exit code is 1 (circuit breaker) and no orphan child processes remain. Note: internal thread/fd state cannot be observed from outside the subprocess.
- `test_heartbeat_thread_cleanup`: run ralph with short timeout (2s) and heartbeat interval (1s) for 3 iterations → ralph exits cleanly (no hang). Verify no orphan child processes remain after exit.

---

### Task 13: State transition path coverage

**Files:**
- Modify: `tests/ralph-loop/test_ralph_loop.py`
- Test: `tests/ralph-loop/test_ralph_loop.py`

**Verify:** `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_happy_path_complete tests/ralph-loop/test_ralph_loop.py::test_skip_then_complete tests/ralph-loop/test_ralph_loop.py::test_timeout_then_stale_then_breaker -v`

**What to implement:**

State transition path tests using KIRO_CMD scripts that manipulate the plan:

- `test_happy_path_complete`: KIRO_CMD script checks off all items → ralph exits 0, summary says SUCCESS
- `test_skip_then_complete`: KIRO_CMD script marks item 1 as SKIP, checks off item 2 → ralph exits 0 (all resolved)
- `test_timeout_then_stale_then_breaker`: KIRO_CMD=sleep 60, timeout=2, max_iter=4 → ralph hits circuit breaker, exits 1

---

### Task 14: Plan format half-corruption fallback

**Files:**
- Modify: `tests/ralph-loop/test_plan.py`
- Modify: `tests/ralph-loop/test_ralph_loop.py`
- Test: `tests/ralph-loop/test_ralph_loop.py`

**Verify:** `python3 -m pytest tests/ralph-loop/test_plan.py::test_partial_task_parse tests/ralph-loop/test_ralph_loop.py::test_fully_unparseable_plan_fallback tests/ralph-loop/test_ralph_loop.py::test_partial_parse_still_batches -v`

**What to implement:**

- `test_partial_task_parse` (test_plan.py): plan with 5 task headers but 2 are malformed (missing `### Task N:` pattern) → `parse_tasks()` returns 3 valid tasks
- `test_partial_parse_still_batches` (test_ralph_loop.py): plan with 4 checklist items but only 2 parseable task sections → `unchecked_tasks()` returns ≤2 tasks → ralph uses batch mode for those (does NOT fall back to build_prompt). Verify stdout contains "batch".
- `test_fully_unparseable_plan_fallback` (test_ralph_loop.py): plan with checklist items but zero parseable task sections (no `### Task N:` headers at all) → `unchecked_tasks()` returns [] but `unchecked > 0` → ralph falls back to `build_prompt()` (item-by-item mode). Verify no crash and no "batch" in stdout.

## Checklist

- [ ] conftest.py fixtures 可用 | `python3 -c "from pathlib import Path; assert Path('tests/ralph-loop/conftest.py').exists()" && python3 -m pytest tests/ralph-loop/ --co -q`
- [ ] scheduler 参数化等价类全通过 | `python3 -m pytest tests/ralph-loop/test_scheduler.py -v`
- [ ] checklist 边界条件全通过 | `python3 -m pytest tests/ralph-loop/test_plan.py::test_counts_with_extra_whitespace tests/ralph-loop/test_plan.py::test_counts_mixed_skip_states tests/ralph-loop/test_plan.py::test_reload_after_external_modify tests/ralph-loop/test_plan.py::test_task_count_mismatch_more_checklist tests/ralph-loop/test_plan.py::test_task_count_mismatch_fewer_checklist tests/ralph-loop/test_plan.py::test_checklist_with_skip_positional tests/ralph-loop/test_plan.py::test_parse_tasks_malformed_header -v`
- [ ] prompt 结构契约断言全通过 | `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_parallel_prompt_structure tests/ralph-loop/test_ralph_loop.py::test_sequential_prompt_structure tests/ralph-loop/test_ralph_loop.py::test_prompt_iteration_number tests/ralph-loop/test_ralph_loop.py::test_prompt_file_paths -v`
- [ ] batch 重算测试通过 | `python3 -m pytest tests/ralph-loop/test_plan.py::test_recompute_after_partial_completion tests/ralph-loop/test_scheduler.py::test_rebatch_after_removal -v`
- [ ] summary 输出验证通过 | `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_summary_success tests/ralph-loop/test_ralph_loop.py::test_summary_failure -v`
- [ ] lock 竞争测试通过 | `python3 -m pytest tests/ralph-loop/test_lock.py::test_concurrent_acquire tests/ralph-loop/test_ralph_loop.py::test_double_ralph_no_lock_guard -v`
- [ ] 信号清理测试通过 | `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_sigint_cleanup tests/ralph-loop/test_ralph_loop.py::test_child_process_no_orphan -v`
- [ ] 异常输入容错通过 | `python3 -m pytest tests/ralph-loop/test_plan.py::test_truncated_plan tests/ralph-loop/test_plan.py::test_binary_content_in_plan tests/ralph-loop/test_ralph_loop.py::test_active_points_to_missing_file tests/ralph-loop/test_ralph_loop.py::test_empty_active_file -v`
- [ ] 外部干扰恢复通过 | `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_plan_modified_during_iteration tests/ralph-loop/test_ralph_loop.py::test_lock_deleted_during_run -v`
- [ ] 并发 reload 无崩溃 | `python3 -m pytest tests/ralph-loop/test_plan.py::test_concurrent_reload -v`
- [ ] 慢测试通过 | `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_many_iterations_no_hang tests/ralph-loop/test_ralph_loop.py::test_heartbeat_thread_cleanup -v`
- [ ] 状态转换路径通过 | `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_happy_path_complete tests/ralph-loop/test_ralph_loop.py::test_skip_then_complete tests/ralph-loop/test_ralph_loop.py::test_timeout_then_stale_then_breaker -v`
- [ ] 半损坏 plan fallback 通过 | `python3 -m pytest tests/ralph-loop/test_plan.py::test_partial_task_parse tests/ralph-loop/test_ralph_loop.py::test_fully_unparseable_plan_fallback tests/ralph-loop/test_ralph_loop.py::test_partial_parse_still_batches -v`
- [ ] 全部测试通过（含新增） | `python3 -m pytest tests/ralph-loop/ -v`

## Errors

| Error | Task | Attempt | Resolution |
|-------|------|---------|------------|

## Findings

- Review quality analysis revealed: angles with concrete analysis methods (like Verify Correctness) produce significantly better output than angles with vague missions. Fixed by adding explicit analysis methods to all 7 random pool angles and strengthening Goal Alignment in `skills/planning/SKILL.md`.
- Socratic check found: Tasks 6/7/8 write `.ralph-result` and `.ralph-loop.lock` to project root (hardcoded in ralph_loop.py). This is a pre-existing design issue — changing runtime paths is out of scope (Non-Goals). Tests must clean up these files in teardown. Existing test `test_lock_cleanup_on_signal` has the same issue.
- Socratic check found: PlanFile's `checked`, `unchecked`, `total` properties are three independent regex scans on `_text`. Not atomic — concurrent `reload()` can replace `_text` between calls. Task 11 assertion corrected accordingly.
- Socratic check #2 found: Task 3 `test_counts_with_extra_whitespace` had ambiguous expectation. Regex `^- \[x\] ` requires line-start — indented items are NOT counted. Clarified.
- Socratic check #2 found: Task 9 `test_binary_content_in_plan` expected "no exception" but `PlanFile.read_text()` raises `UnicodeDecodeError` on non-UTF-8 bytes. Corrected to expect the exception (Non-Goals: no runtime changes).
- Socratic check #2 found: Task 12 fd leak detection via `/dev/fd` is infeasible from outside subprocess — fd is released when process exits. Removed, kept thread leak check only.
- Socratic check #3 found: Task 2 "chain overlap A→B→C→D → 4 sequential batches" was wrong. Greedy algorithm groups non-adjacent tasks (A+C, B+D) into parallel batches since they have no direct file overlap. Fixed: added as separate case with correct expectation, replaced original with "all share same file → 4 sequential".
- Socratic check #3 found: Task 7 `test_double_ralph_blocked` expected lock contention rejection, but `LockFile.acquire()` is unconditional `write_text()` — no guard. Renamed to `test_double_ralph_no_lock_guard`, expectation changed to "both run, no crash".
- Socratic check #3 found: Task 1 Verify field still had old broken command (`echo "exit:$?"`), only checklist was fixed. Synced.
- Socratic check #3 found: Task 8 orphan detection via `ps` for `sleep` is flaky (other sleep processes exist). Changed to use uniquely-named script.
- Socratic check #4 found: Task 9 `test_empty_active_file` expected "clear error" but `Path('')` resolves to cwd, causing `IsADirectoryError` crash. Corrected to expect `returncode != 0` with unhandled exception.
- Socratic check #5 found: Task 12 thread leak detection via `threading.active_count()` is also infeasible from outside subprocess (same reason as fd leak). Subprocess threads are invisible to parent process. Changed both slow tests to verify clean exit (no hang) and no orphan child processes — observable from outside.
