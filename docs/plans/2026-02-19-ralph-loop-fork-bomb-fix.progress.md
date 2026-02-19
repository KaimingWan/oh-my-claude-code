# Progress: Ralph Loop Fork Bomb Fix

## Parallel Execution — 2026-02-19

Tasks 1 and 2 dispatched to executor subagents in parallel (Strategy D).

---

## Task 1: Precheck Excludes Ralph Tests (Root Cause)
- **Status:** done
- **Files changed:** `scripts/lib/precheck.py`, `tests/ralph-loop/test_precheck.py`
- **What was done:** Added `--ignore=tests/ralph-loop` to the pytest command in `detect_test_command()`. Added `test_precheck_excludes_ralph_tests` to the test file.
- **Verify:** `python3 -m pytest tests/ralph-loop/test_precheck.py -v` → 6 passed

---

## Task 2: Ralph Loop Recursion Guard (Safety Net)
- **Status:** done
- **Files changed:** `scripts/ralph_loop.py`, `tests/ralph-loop/test_ralph_loop.py`
- **What was done:** Added recursion guard after `die()` definition — checks `_RALPH_LOOP_RUNNING` env var and dies immediately if set, then sets it to `"1"` for child processes. Added `test_recursion_guard` to the test file.
- **Verify:** `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_recursion_guard -v` → 1 passed

---

## Commit
`6f6d971` — fix: eliminate ralph loop fork bomb via precheck exclusion and recursion guard

---

## Iteration 2 — 2026-02-19

## Task 3: Fix Orphan Child Processes
- **Status:** done
- **Files changed:** `scripts/ralph_loop.py`, `tests/ralph-loop/test_ralph_loop.py`
- **What was done:**
  1. Added module-level `_child_proc: subprocess.Popen | None = None` to track active child.
  2. Updated `_cleanup_handler` to call `os.killpg(os.getpgid(_child_proc.pid), signal.SIGTERM)` before releasing the lock — this kills the entire process group of the child when ralph is SIGTERMed or SIGINTed.
  3. Assigned `_child_proc = proc` immediately after `subprocess.Popen(...)` in the main loop (module-level assignment, no `global` needed).
  4. Added `test_no_orphan_after_ralph_killed` test: spawns ralph with a uniquely-named sleep child, polls until child appears, sends SIGTERM to ralph, waits, then asserts `pgrep` finds no orphan.
- **Learnings:** Module-level variables assigned inside `for`/`with` blocks at module scope do NOT need `global` declaration — that's only needed inside function bodies. The `start_new_session=True` is preserved (required for timeout `killpg`); the new handler only fires on SIGTERM/SIGINT paths, not the timeout path which already kills via `killpg` directly.
- **Verify:** `python3 -m pytest tests/ralph-loop/test_ralph_loop.py::test_no_orphan_after_ralph_killed -v` → 1 passed. Full regression (all non-slow tests) → all passed.
