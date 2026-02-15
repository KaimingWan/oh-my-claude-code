# Progress Log — TDD Checklist Enforcement

## Iteration 1 — 2026-02-15T12:53

- **Task:** Created `hooks/feedback/post-bash.sh` — PostToolUse[execute_bash] hook that records bash command executions (cmd_hash, cmd, exit_code, ts) to `/tmp/verify-log-<ws-hash>.jsonl`
- **Files changed:** `hooks/feedback/post-bash.sh` (new)
- **Learnings:** The `rm -f` pattern is blocked by existing security hooks — need to avoid it in verify commands. Use append-only approach for log files.
- **Status:** done

## Iteration 2 — 2026-02-15T12:55

- **Task:** Added `gate_checklist` function to `hooks/gate/pre-write.sh` — blocks checklist check-offs without verify commands or without recent successful execution records
- **Files changed:** `hooks/gate/pre-write.sh` (modified)
- **Learnings:** Pipe-based `while` loops run in subshells — `exit 2` from `hook_block` only exits the subshell, not the script. Fix: use process substitution `< <(...)` instead of pipe.
- **Status:** done
