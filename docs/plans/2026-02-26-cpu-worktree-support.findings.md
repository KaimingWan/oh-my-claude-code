# Findings

## Decision: Single atomic rewrite
All checklist items map to a single file (`commands/cpu.md`). The plan's Step 2 specifies verbatim content that satisfies all 7 verify commands simultaneously. No incremental approach needed.

## Design notes
- Step 4A uses `git branch -d` (safe delete — only works if branch is already merged). Step 4B does NOT delete the local branch since the PR hasn't merged yet.
- Merge conflict in 4A triggers automatic fallback to 4B (PR creation) — ensures no data loss.
- `--porcelain` check on main worktree prevents merge into dirty state.
