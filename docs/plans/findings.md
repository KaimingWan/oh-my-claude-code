# Findings — TDD Checklist Enforcement

## Pipe vs Process Substitution in Bash Hooks

**Problem:** `echo "$CONTENT" | grep ... | while read` runs the while loop in a subshell. `exit 2` inside the loop only exits the subshell, not the parent script. The hook appears to succeed (exit 0) even when it should block.

**Solution:** Use process substitution: `while read ...; do ... done < <(echo "$CONTENT" | grep ...)`. This runs the loop in the current shell, so `exit 2` propagates correctly.

**Rule:** All hooks that iterate over filtered content and may need to `exit 2` must use process substitution, never pipe-based while loops.

## Live Lock Testing in Hooks

**Problem:** Using background processes (`bash -c 'echo $$ > lock; sleep 5' &`) in test suites causes hangs when the test runner exits before the background process.

**Solution:** Use the current shell's PID (`$$`) as the live lock PID — it's guaranteed alive during test execution. No background processes needed.

## Consolidated Hook Design (enforce-ralph-loop)

**Decision:** Single hook handles both `execute_bash` and `fs_write` via MODE variable, registered twice in default.json with different matchers. This is cleaner than embedding ralph-loop checks in pre-write.sh (separation of concerns).

**Key patterns:**
- `case "$TOOL_NAME" in ... MODE="bash" / MODE="write"` for tool dispatch
- Path-based allowlist via `case "$FILE" in` for fs_write (simpler than regex)
- Strict read-only allowlist + chain rejection for execute_bash (no `&&`, `||`, `;`, `|`, `>`, backticks, `$(`)
