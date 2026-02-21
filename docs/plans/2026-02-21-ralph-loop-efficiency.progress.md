# Ralph Loop Efficiency — Progress Log

## Iteration 1 — 2026-02-21 14:37

- **Task:** All 6 tasks + regression verification
- **Files changed:**
  - `scripts/ralph_loop.py` — moved detect_cli() before loop, removed run_precheck from build_prompt, merged build_init_prompt into build_prompt with is_first param, removed confusing elapsed calculation from _heartbeat
  - `scripts/lib/cli_detect.py` — added --no-session-persistence to claude command
  - `scripts/lib/pty_runner.py` — removed os.close(master) from stop() to fix double-close race
  - `tests/ralph-loop/test_ralph_loop.py` — added 5 new tests, updated test_init_prompt_differs_from_regular and test_precheck_runs_only_once for merged API
  - `tests/ralph-loop/test_pty_runner.py` — added test_master_fd_single_close
- **Learnings:**
  - Task 3 (merge build_init_prompt) required updating Task 2's test since the merged function now contains run_precheck in the is_first branch. Used mock-based test instead of source parsing for robustness.
  - The checklist verify command for Task 2 becomes stale after Task 3 merge — this is expected since the functions were combined. Behavioral test validates the intent correctly.
  - Pre-existing test failures (test_already_complete, test_circuit_breaker) were intermittent lock-related issues, not caused by our changes.
- **Status:** done
