## Iteration 8 — 2026-02-21

- **Task:** config validation passes (Task 8)
- **Command:** `python3 scripts/generate_configs.py --validate`
- **Result:** ✅ Hook registry is consistent with files on disk.
- **Status:** done

## Iteration 7 — 2026-02-21

- **Task:** regression tests pass (Task 7)
- **Command:** `bash tests/hooks/test-kiro-compat.sh`
- **Result:** 19 passed, 0 failed
- **Status:** done

## Iteration 6 — 2026-02-21

- **Task:** feedback output slimmed (Task 6)
- **Files changed:**
  - `hooks/gate/pre-write.sh` — inject_plan_context: always 1-line summary (removed full checklist every-5-writes branch)
  - `hooks/feedback/post-write.sh` — test failure tail: changed tail -10 to tail -3
  - `hooks/feedback/verify-completion.sh` — unchecked summary: removed listing of individual items, 1-line count only
  - `tests/hooks/test-feedback-output.sh` — created 5-test suite
- **Learnings:**
  - pre-write inject_plan_context was outputting full checklist (20 lines) every 5 writes. Removed throttle+full-checklist entirely; always 1-line.
  - verify-completion was listing all unchecked items. Changed to 1-line summary.
- **Status:** done

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

## Iteration 5 — 2026-02-21

- **Task:** context-enrichment output <=8 lines (Task 5)
- **Files changed:**
  - `hooks/feedback/context-enrichment.sh` — added 60s dedup (DEDUP_FILE), emit() helper for buffered output, MAX_RULES=3 cap in rules injection, output truncation to max 8 lines at end
  - `tests/hooks/test-context-budget.sh` — created 5-test suite: output <=8 lines, research keyword triggers, 60s dedup suppression, rules cap with 10→3, truncation under 8 lines
- **Learnings:**
  - printf '- [ ] item' fails with "invalid option" — the leading dash is parsed as a flag. Use heredoc or cat for content with leading dashes.
  - _RALPH_LOOP_RUNNING env var leak from shell session doesn't affect test isolation since each hook invocation is a fresh subprocess.
  - The .active pointer must point to an existing plan file for Write tool access to work correctly. Stale pointers cause the time-window fallback to kick in.
- **Status:** done

## Iteration 4 — 2026-02-21

- **Task:** block output <=3 lines (Task 4)
- **Files changed:**
  - `hooks/_lib/block-recovery.sh` — compressed RETRY/SKIP messages to single inline suffix: `| ⚡ RETRY (N/3)` or `| ⛔ SKIP`
  - `hooks/security/block-dangerous.sh` — single-line block messages
  - `hooks/security/block-secrets.sh` — single-line block messages
  - `hooks/security/block-sed-json.sh` — single-line block messages with jq hint
  - `hooks/security/block-outside-workspace.sh` — single-line block messages
  - `tests/hooks/test-block-output.sh` — created 8-test suite checking output <= 3 lines per hook
- **Learnings:**
  - All block output collapses to 1 line since both the block message and the retry suffix are on one line. Max is 1, well under 3.
  - The test checks actual stderr line count from each hook invocation.
- **Status:** done

## Iteration 3 — 2026-02-21

- **Task:** block-outside-workspace allow /tmp/ (Task 3)
- **Files changed:**
  - `hooks/security/block-outside-workspace.sh` — removed `/tmp/` from OUTSIDE_WRITE_PATTERNS bash redirect patterns. Write/Edit workspace boundary check unchanged.
  - `tests/hooks/test-outside-workspace.sh` — created 11-test suite
  - `tests/hooks/test-cc-compat.sh` — updated bash /tmp/ test from BLOCK to ALLOW, added /etc/ block test
- **Learnings:**
  - /tmp/ removal only affects bash redirect patterns; Write/Edit path check (workspace boundary) still blocks /tmp/ writes correctly.
  - CC compat test needed updating since the behavior intentionally changed.
- **Status:** done

## Iteration 2 — 2026-02-21

- **Task:** block-dangerous.sh narrowing (Task 2)
- **Files changed:**
  - `hooks/_lib/patterns.sh` — split into DANGEROUS_BASH_PATTERNS (case-sensitive) and DANGEROUS_BASH_PATTERNS_NOCASE (case-insensitive for SQL). Narrowed: git branch only force-delete flag (not soft-delete), removed kill/killall/pkill, find -delete/-exec rm only on system paths
  - `hooks/security/block-dangerous.sh` — second loop for NOCASE patterns using grep -qiE; main loop uses grep -qE (case-sensitive)
  - `tests/hooks/verify-block-dangerous.sh` — rewrote from single-case to 20-test suite
- **Learnings:**
  - grep -qiE (case-insensitive) was causing git branch force-delete pattern to also match soft-delete. Fix: use -qE for case-sensitive patterns, separate array for case-insensitive SQL patterns.
  - find system path pattern must not require trailing slash — bash find uses `find /etc` not `find /etc/`. Updated pattern accordingly.
  - Cannot test dangerous patterns by embedding them in shell debug heredocs — the hook scans the heredoc content too.
- **Status:** done
