# Findings — TDD Checklist Enforcement

## Pipe vs Process Substitution in Bash Hooks

**Problem:** `echo "$CONTENT" | grep ... | while read` runs the while loop in a subshell. `exit 2` inside the loop only exits the subshell, not the parent script. The hook appears to succeed (exit 0) even when it should block.

**Solution:** Use process substitution: `while read ...; do ... done < <(echo "$CONTENT" | grep ...)`. This runs the loop in the current shell, so `exit 2` propagates correctly.

**Rule:** All hooks that iterate over filtered content and may need to `exit 2` must use process substitution, never pipe-based while loops.
