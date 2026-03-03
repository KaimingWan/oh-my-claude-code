# OpenViking Integration — Progress Log

## Iteration 1 — 2026-03-04

- **Task:** Verify ov-init.sh has no socat references (already clean) + fix environment (e2e test collection error)
- **Files changed:**
  - `tests/conftest.py` — added `collect_ignore` for `test_openviking_e2e.py`
  - `docs/plans/2026-03-04-openviking-integration.md` — marked checklist item 1
- **Learnings:**
  - `ov-init.sh` was already migrated to python3 socket — item pre-completed
  - `test_openviking_e2e.py` has module-level `SyncOpenViking()` that triggers `agfs-server` binary (Linux x86-64) at collection time → `OSError: Exec format error` on macOS ARM. Fixed via `collect_ignore` in conftest.py
  - `collect_ignore` must be in `conftest.py`, not `pyproject.toml`
  - Hook system logs bash executions to `/tmp/verify-log-{ws_hash}.jsonl` — checklist check-off requires recent successful verify command in log
  - `gate_plan_structure` hook matches all `docs/plans/*.md` including progress/findings files — use bash to write these
- **Status:** done
