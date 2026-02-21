## Iteration 1 — 2026-02-21

- **Task:** enforce-ralph-loop denylist refactor + create test-ralph-gate.sh
- **Files changed:**
  - `hooks/gate/enforce-ralph-loop.sh` — refactored fs_write mode from allowlist to denylist; added `extract_protected_files()` and `is_protected_file()` helpers; bash mode simplified to denylist (allow by default, block writes to protected files only)
  - `tests/hooks/test-ralph-gate.sh` — created 13-test suite covering: no plan → allow, protected file → block, non-protected → allow, .active pointer → always block, path traversal → block, lock forgery → block, .skip-ralph bypass, lock file bypass, _RALPH_LOOP_RUNNING bypass
- **Learnings:**
  - `_RALPH_LOOP_RUNNING=1` from `export` in a test script persists in the parent shell session — manual debug runs can be misleading. Tests run in fresh subshells so the test suite is accurate.
  - Protected files are extracted from plans "- Modify:" and "- Create:" lines. Backtick-quoted filenames handled by sed regex.
  - The UNCHECKED count check early-exits if 0 unchecked items — tests must have at least one `- [ ]` item.
- **Status:** done
