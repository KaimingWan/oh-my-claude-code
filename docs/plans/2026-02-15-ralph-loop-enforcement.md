# Ralph-Loop Enforcement Redesign

**Goal:** Ensure agent cannot bypass ralph-loop.sh when executing an active plan with unchecked checklist items, covering all tool vectors (execute_bash + fs_write), session restart scenarios, and edge cases.
**Architecture:** Single consolidated PreToolUse hook (enforce-ralph-loop.sh) handling both execute_bash and fs_write, with PID-based lock validation. Ralph-loop.sh writes PID to lock file; hook validates PID is alive. Stale locks auto-cleaned.
**Tech Stack:** Bash hooks, jq, Kiro hook system (PreToolUse exit 2 = hard block)

## Current State (what exists)

1. `hooks/gate/enforce-ralph-loop.sh` — PreToolUse[execute_bash] gate, checks .active plan + lock PID + read-only allowlist
2. `hooks/gate/pre-write.sh` — PreToolUse[fs_write], has ralph-loop check embedded in gate_check() but only for source files (is_source_file filter)
3. `scripts/ralph-loop.sh` — writes `$$` to `.ralph-loop.lock`, trap removes on exit
4. `.kiro/agents/default.json` — enforce-ralph-loop registered for execute_bash only

## Known Vulnerabilities in Current Implementation

1. **pre-write.sh ralph check is gated by `is_source_file`** — non-source files (e.g., markdown, config, SKILL.md) bypass the ralph-loop check entirely. Plan tasks often modify .md files.
2. **Read-only allowlist is regex-based and fragile** — `echo` is allowed but `echo "x" > file` writes. Multi-line commands with `&&` can chain read-only prefix with write operations.
3. **No fs_write-specific hook registration** — enforce-ralph-loop.sh only registered for execute_bash, not fs_write. The fs_write check lives inside pre-write.sh's gate_check which has the is_source_file gate.
4. **Lock file race condition** — between `kill -0` check and actual tool execution, ralph-loop could exit. Low risk but theoretically possible.
5. **Agent can delete .active file** — `rm docs/plans/.active` (if not blocked by dangerous command hook) removes the trigger, disabling all enforcement.
6. **Agent can mark checklist items done without verification** — sed/awk on the plan file to flip `- [ ]` to `- [x]` bypasses the verify-before-check hook.

## Design Decision

**Consolidate into one hook** that handles both execute_bash and fs_write, registered twice in default.json. Remove the ralph-loop check from pre-write.sh (separation of concerns — pre-write handles workflow gate, enforce-ralph-loop handles execution discipline).

## Tasks

### Task 1: Rewrite enforce-ralph-loop.sh

**Files:**
- Modify: `hooks/gate/enforce-ralph-loop.sh`

**Changes:**
- Handle both `execute_bash` and `fs_write` tool names
- For execute_bash: keep read-only allowlist but tighten it (match full command, not prefix; exclude commands with `>`, `>>`, `|`, `&&` after read-only prefix)
- For fs_write: block all writes to non-plan-metadata files (allow writes to docs/plans/*.md for review sections, block everything else)
- Lock validation: PID check with `kill -0`, stale lock cleanup
- Allow: ralph-loop.sh command, writes to the plan file itself (reviewer needs to write review), reads/inspections

**Read-only allowlist (tightened):**
Strict allowlist approach — only these commands pass, everything else blocked:
- `git status|log|diff|show|branch|stash list`
- `ls`, `cat`, `head`, `tail`, `wc`, `file`, `stat`
- `grep`, `awk '...'` (read-only awk), `sed -n` (read-only sed)
- `test`, `[`, `md5`, `shasum`, `date`, `pwd`, `which`, `type`
- `jq` (read-only), `printf` (to stdout only)
- Command must NOT contain: `>`, `>>`, `&&`, `||`, `;`, `|`, backticks, `$(` (no chaining/piping/subshells)
- Single simple command only

**For fs_write:** Allow writes to:
- `docs/plans/*.md` (plan files — but path must normalize to docs/plans/, reject `..`)
- `docs/plans/.active` (plan pointer)
- `docs/plans/.ralph-result` (ralph-loop result)
- `knowledge/*.md` (auto-capture — .md only, no executables)
- `.completion-criteria.md`

Block writes to:
- `.ralph-loop.lock` (prevent lock forgery)
- Everything else when plan active + unchecked + no ralph-loop

Path validation: reject any path containing `..` after normalization.

### Task 2: Register hook for fs_write

**Files:**
- Modify: `.kiro/agents/default.json`

**Changes:**
- Add `{"matcher": "fs_write", "command": "hooks/gate/enforce-ralph-loop.sh"}` to preToolUse
- This makes enforce-ralph-loop.sh fire for both execute_bash and fs_write

### Task 3: Remove ralph-loop check from pre-write.sh

**Files:**
- Modify: `hooks/gate/pre-write.sh`

**Changes:**
- Remove the ralph-loop enforcement block from gate_check() (lines that check PLAN_PTR, RALPH_LOCK, UNCHECKED, RALPH_OK)
- pre-write.sh goes back to its original responsibility: workflow gate (plan exists + reviewed before creating source files)

### Task 4: Protect .active file and lock file from manipulation

**Files:**
- Modify: `hooks/gate/enforce-ralph-loop.sh`

**Changes:**
- For execute_bash: block commands that delete/overwrite `.active` when plan has unchecked items
- For fs_write: block writes to `.ralph-loop.lock` (prevent lock forgery)
- Path validation: reject any file_path containing `..` (prevent traversal)

### Task 5: Integration tests

**Files:**
- Create: `tests/ralph-loop/test-enforcement.sh`

**Test cases:**

| ID | Scenario | Tool | Command/File | Expected |
|----|----------|------|-------------|----------|
| T1 | bash blocked when plan active | execute_bash | `mkdir -p foo` | exit 2 |
| T2 | ralph-loop.sh allowed | execute_bash | `./scripts/ralph-loop.sh` | exit 0 |
| T3 | read-only allowed | execute_bash | `git status` | exit 0 |
| T4 | read-only with chain blocked | execute_bash | `cat foo && mkdir bar` | exit 2 |
| T5 | fs_write to source blocked | fs_write | create `src/foo.sh` | exit 2 |
| T6 | fs_write to plan allowed | fs_write | str_replace `docs/plans/x.md` | exit 0 |
| T7 | stale lock cleaned + blocked | execute_bash | dead PID in lock | exit 2 + lock removed |
| T8 | live lock allows | execute_bash | live PID in lock | exit 0 |
| T9 | no active plan = no block | execute_bash | no .active file | exit 0 |
| T10 | all items checked = no block | execute_bash | all `- [x]` | exit 0 |
| T11 | delete .active blocked | execute_bash | `rm docs/plans/.active` | exit 2 |
| T12 | knowledge .md write allowed | fs_write | create `knowledge/foo.md` | exit 0 |
| T13 | path traversal blocked | fs_write | create `docs/plans/../../evil.sh` | exit 2 |
| T14 | lock forgery blocked | fs_write | create `.ralph-loop.lock` | exit 2 |
| T15 | knowledge non-md blocked | fs_write | create `knowledge/evil.sh` | exit 2 |
| T16 | .skip-ralph bypass works | execute_bash | `mkdir x` + `.skip-ralph` exists | exit 0 + warning |

## Checklist

- [x] enforce-ralph-loop.sh handles both execute_bash and fs_write | `grep -q 'execute_bash\|Bash' hooks/gate/enforce-ralph-loop.sh && grep -q 'fs_write\|Write' hooks/gate/enforce-ralph-loop.sh`
- [x] fs_write registered in default.json | `jq '.hooks.preToolUse[] | select(.command == "hooks/gate/enforce-ralph-loop.sh")' .kiro/agents/default.json | grep -q 'fs_write'`
- [x] pre-write.sh has NO ralph-loop check | `! grep -q 'ralph-loop\|RALPH_LOCK\|ralph_loop' hooks/gate/pre-write.sh`
- [ ] read-only allowlist rejects chained writes | `echo '{"tool_name":"execute_bash","tool_input":{"command":"cat foo && mkdir bar"}}' | bash hooks/gate/enforce-ralph-loop.sh 2>&1; test $? -eq 2`
- [ ] fs_write to plan file allowed | `echo '{"tool_name":"fs_write","tool_input":{"file_path":"docs/plans/test.md","command":"str_replace"}}' | bash hooks/gate/enforce-ralph-loop.sh 2>&1; test $? -eq 0`
- [ ] fs_write to source file blocked | `echo '{"tool_name":"fs_write","tool_input":{"file_path":"src/foo.sh","command":"create"}}' | bash hooks/gate/enforce-ralph-loop.sh 2>&1; test $? -eq 2`
- [ ] stale lock (dead PID) cleaned and blocked | `echo "99999999" > .ralph-loop.lock && echo '{"tool_name":"execute_bash","tool_input":{"command":"mkdir x"}}' | bash hooks/gate/enforce-ralph-loop.sh 2>&1; RC=$?; [ ! -f .ralph-loop.lock ] && [ $RC -eq 2 ]`
- [ ] delete .active blocked | `echo '{"tool_name":"execute_bash","tool_input":{"command":"rm docs/plans/.active"}}' | bash hooks/gate/enforce-ralph-loop.sh 2>&1; test $? -eq 2`
- [ ] test suite has ≥15 cases | `grep -c 'begin_test' tests/ralph-loop/test-enforcement.sh | awk '{exit ($1 >= 15 ? 0 : 1)}'`
- [ ] all tests pass | `bash tests/ralph-loop/test-enforcement.sh 2>&1 | grep -q "全部通过"`
- [ ] path traversal blocked | `echo '{"tool_name":"fs_write","tool_input":{"file_path":"docs/plans/../../evil.sh","command":"create"}}' | bash hooks/gate/enforce-ralph-loop.sh 2>&1; test $? -eq 2`
- [ ] lock forgery blocked | `echo '{"tool_name":"fs_write","tool_input":{"file_path":".ralph-loop.lock","command":"create"}}' | bash hooks/gate/enforce-ralph-loop.sh 2>&1; test $? -eq 2`
- [ ] knowledge non-md blocked | `echo '{"tool_name":"fs_write","tool_input":{"file_path":"knowledge/evil.sh","command":"create"}}' | bash hooks/gate/enforce-ralph-loop.sh 2>&1; test $? -eq 2`
- [ ] hook syntax valid | `bash -n hooks/gate/enforce-ralph-loop.sh`
- [ ] .skip-ralph bypass works | `touch .skip-ralph && echo '{"tool_name":"execute_bash","tool_input":{"command":"mkdir x"}}' | bash hooks/gate/enforce-ralph-loop.sh 2>&1; RC=$?; rm -f .skip-ralph; test $RC -eq 0`
- [ ] no real files modified by tests | `md5 -q docs/plans/.active hooks/gate/enforce-ralph-loop.sh > .pre-test.md5 && bash tests/ralph-loop/test-enforcement.sh > /dev/null 2>&1 && md5 -q docs/plans/.active hooks/gate/enforce-ralph-loop.sh | diff .pre-test.md5 -`

## Round 1 Review (Security, Technical Feasibility, Completeness, Testability)

- Security: REJECT — path traversal in fs_write allowlist, heredoc/indirect write bypass, lock file forgery, checklist manipulation
- Technical Feasibility: APPROVE
- Completeness: REJECT — docs/plans/ and knowledge/ write allowance too broad
- Testability: APPROVE

**Fixes applied:**
1. fs_write path validation: use realpath/normalization, reject `..` in paths
2. execute_bash: switch from denylist to strict allowlist (only known read-only commands, reject everything else)
3. Lock file protection: block fs_write to `.ralph-loop.lock`
4. knowledge/ writes: restrict to `.md` files only
5. Checklist manipulation: already covered by verify-completion hook (requires verify command evidence to check off items), no additional protection needed
6. Added test cases T13-T15 for path traversal, lock forgery, knowledge abuse

## Round 2 Review (Compatibility, Rollback Safety, Clarity, YAGNI)

- Compatibility: APPROVE
- Rollback Safety: REJECT — no emergency bypass; hook bug blocks ALL operations (both execute_bash + fs_write)
- Clarity: APPROVE
- YAGNI: APPROVE

**Fix applied:**
- Add `.skip-ralph` bypass file (like `.skip-plan` for pre-write.sh). If `.skip-ralph` exists, hook exits 0 immediately with warning. User can create this file manually via filesystem if hook malfunctions. Added test case T16 and checklist item for bypass.
