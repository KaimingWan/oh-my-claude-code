## Iteration 1 — 2026-02-21

- **Task:** Environment fix + all plan items
- **Status:** done
## Iteration 1 — 2026-02-21

- **Task:** Environment fix + all 5 unchecked plan items + architecture doc update
- **Files changed:**
  - tests/test_debug_hook_trigger.py — fix 60s dedup: use (cwd + newline).encode() to match bash pwd|shasum hash
  - hooks/dispatch-pre-bash.sh — new dispatcher for PreToolUse[execute_bash]
  - hooks/dispatch-pre-write.sh — new dispatcher for PreToolUse[fs_write]
  - tests/hooks/test-dispatch-pre-bash.sh — 6 tests
  - tests/hooks/test-dispatch-pre-write.sh — 5 tests
  - scripts/generate_configs.py — DISPATCH_PRE_BASH/WRITE constants + validate() self-scan for dispatchers
  - hooks/_lib/block-recovery.sh — add 2>/dev/null to mv in cleanup
  - docs/designs/2026-02-18-hook-architecture.md — Dispatcher Pattern section + registry + matrix
- **Learnings:**
  - pwd|shasum adds trailing newline; Python must use (cwd + LF).encode() to get same hash
  - enforcement.md is hook-protected (human-only); dispatchers registered via self-scan in generate_configs.py
  - printf %.200s is bash 3.2 safe; ${var:0:200} requires bash 4+
- **Status:** done
