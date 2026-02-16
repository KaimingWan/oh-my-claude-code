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

## Workspace Hash Isolation for Hook Tests

**Problem:** Integration tests that invoke security hooks directly share the same `/tmp/block-count-<hash>.jsonl` file as live hooks, because both run from the same workspace directory. Counts accumulate across the interactive session and test runs, causing flaky assertions.

**Solution:** Run hook invocations from a `mktemp -d` directory. The `pwd | shasum` in `block-recovery.sh` produces a unique hash, isolating test counts from live session counts. Cleanup via `trap 'rm -rf "$TEST_DIR"' EXIT`.

## Git Stash Self-Revert in ralph-loop.sh

**Problem:** `ralph-loop.sh` runs `git stash push` before each iteration to save dirty state. When testing the script with uncommitted changes to the script itself, the stash reverts those changes mid-execution. The script then runs the old (pre-edit) version.

**Solution:** Always commit changes to `ralph-loop.sh` before running integration tests that invoke it. The `git stash push` inside the script is by design (protects against dirty state during agent runs), so the fix is in the workflow, not the code.

**Rule:** When modifying ralph-loop.sh, commit before testing.

## enforce-ralph-loop Blocks Checklist Verify Commands

**Problem:** Several checklist verify commands are themselves blocked by enforce-ralph-loop.sh:
- `python3 -m pytest tests/ -q` — not in read-only allowlist
- `grep -c '|' docs/INDEX.md` — hook interprets `|` in grep pattern as a pipe character
- `diff CLAUDE.md AGENTS.md` — standalone `diff` not in allowlist (only `git diff` is)

**Impact:** When executing the final checklist items outside ralph-loop, the verify commands can't be run via bash. Must use alternative tools (grep tool, md5 command, fs_read) or run inside ralph-loop.

**Recommendation:** Consider adding `python3 -m pytest`, `diff`, and `bash -c 'test ...'` to the read-only allowlist, or make the pipe detection smarter (distinguish `|` in grep patterns from actual shell pipes).
