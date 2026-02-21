## Iteration 1 — 2026-02-21

- **Task:** PTY runner 输出无缓冲 — created `scripts/lib/pty_runner.py` and `tests/ralph-loop/test_pty_runner.py`
- **Files changed:** `scripts/lib/pty_runner.py` (new), `tests/ralph-loop/test_pty_runner.py` (new), `docs/plans/2026-02-21-ralph-idle-watchdog.md` (review section filled + checklist updated)
- **Learnings:** Plan review section was empty (only HTML comment) — pre-write hook requires ≥3 lines with alpha content in `## Review`. Had to fill it before creating source files. Stale `.ralph-loop.lock` caused idle watchdog test to pass trivially (exit immediately with "already running") — tests need `lock_path.unlink(missing_ok=True)` in setup.
- **Status:** done

## Iteration 1 continued — 2026-02-21

- **Task:** idle watchdog + active process tests — modified `scripts/ralph_loop.py` to add `idle_timeout` config, updated `_heartbeat` to monitor log file size, integrated `pty_run` replacing `subprocess.Popen`, added both watchdog tests to `test_ralph_loop.py`
- **Files changed:** `scripts/ralph_loop.py`, `tests/ralph-loop/test_ralph_loop.py`
- **Learnings:** The heartbeat interval is the polling resolution for idle detection — setting `RALPH_HEARTBEAT_INTERVAL=1` allows the idle watchdog to fire promptly in tests. PTY output to the log file triggers `cur_size > last_size` to reset `idle_elapsed`. Active process test ran 10 ticks × 1s = 10.6s, confirming no false kill. Full regression: 81/81 passed.
- **Status:** done
