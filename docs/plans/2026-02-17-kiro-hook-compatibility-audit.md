# Kiro CLI Hook Compatibility Audit

**Goal:** Audit all 14 hooks (12 wired in Kiro config + 2 unwired) for Kiro CLI compatibility, build a verified compatibility matrix, fix any issues found, and update README.

**Non-Goals:** Adding new hooks; changing hook behavior for Claude Code; redesigning the hook architecture.

**Architecture:** Each hook is a standalone bash script receiving JSON via stdin. Kiro CLI supports 5 hook events (agentSpawn, userPromptSubmit, preToolUse, postToolUse, stop) with the same exit-code semantics as Claude Code (exit 2 = block). The key compatibility risks are: (1) tool_name differences, (2) tool_input field name differences, (3) missing environment variables like `$CLAUDE_PROJECT_DIR`, (4) hook_event_name field presence in Kiro but not CC.

**Tech Stack:** Bash, jq, Kiro CLI 1.26.1

## Hook Inventory

| # | Hook | Kiro Config | Event | Matcher |
|---|------|-------------|-------|---------|
| 1 | security/block-dangerous.sh | ✅ | preToolUse | execute_bash |
| 2 | security/block-secrets.sh | ✅ | preToolUse | execute_bash |
| 3 | security/block-sed-json.sh | ✅ | preToolUse | execute_bash |
| 4 | security/block-outside-workspace.sh | ✅ | preToolUse | execute_bash, fs_write |
| 5 | gate/pre-write.sh | ✅ | preToolUse | fs_write |
| 6 | gate/enforce-ralph-loop.sh | ✅ | preToolUse | execute_bash, fs_write |
| 7 | feedback/correction-detect.sh | ✅ | userPromptSubmit | — |
| 8 | feedback/session-init.sh | ✅ | userPromptSubmit | — |
| 9 | feedback/context-enrichment.sh | ✅ | userPromptSubmit | — |
| 10 | feedback/post-write.sh | ✅ | postToolUse | fs_write |
| 11 | feedback/post-bash.sh | ✅ | postToolUse | execute_bash |
| 12 | feedback/verify-completion.sh | ✅ | stop | — |
| 13 | feedback/auto-capture.sh | ❌ | — | — |
| 14 | feedback/kb-health-report.sh | ❌ | — | — |

## Research Findings

From Kiro CLI docs (https://kiro.dev/docs/cli/hooks/):
- Supported events: agentSpawn, userPromptSubmit, preToolUse, postToolUse, stop
- Hook event JSON: `{"hook_event_name":"...","cwd":"...","tool_name":"...","tool_input":{...}}`
- PreToolUse exit 2 = block (same as CC)
- Matcher uses canonical names: `fs_read`, `fs_write`, `execute_bash`, `use_aws`
- Default timeout: 30s

Key differences from Claude Code:
1. CC tool names: `Bash`, `Write`, `Edit` — Kiro: `execute_bash`, `fs_write`
2. CC hook config: `{"type":"command","command":"bash \"$CLAUDE_PROJECT_DIR\"/hooks/..."}` — Kiro: `{"command":"hooks/..."}`
3. CC stdin: `{"tool_name":"Bash","tool_input":{...}}` — Kiro adds `hook_event_name` and `cwd` fields
4. Kiro fs_write tool_input uses `path` (not `file_path`), `file_text` (not `content`)

## Tasks

### Task 1: Build test harness

**Files:**
- Create: `tests/hooks/test-kiro-compat.sh`

Test harness must:
- Test all 12 wired hooks with Kiro-format JSON stdin
- For each blocking hook (security/* + gate/*): test both BLOCK case (exit 2) and ALLOW case (exit 0)
- For each feedback hook: test it exits 0 on valid input
- Use relative paths (no hardcoded `/Users/...`)
- Output: `PASS hook-name scenario` or `FAIL hook-name scenario`

### Task 2: Audit and fix tool_input field parsing

**Files to audit** (exhaustive list of hooks that parse tool_input):
- `hooks/security/block-outside-workspace.sh` — parses `.tool_input.file_path // .tool_input.path` and `.tool_input.command`
- `hooks/security/block-dangerous.sh` — parses `.tool_input.command`
- `hooks/security/block-secrets.sh` — parses `.tool_input.command`
- `hooks/security/block-sed-json.sh` — parses `.tool_input.command`
- `hooks/gate/pre-write.sh` — parses `.tool_input.file_path // .tool_input.path` and `.tool_input.content // .tool_input.file_text // .tool_input.new_str`
- `hooks/gate/enforce-ralph-loop.sh` — parses `.tool_input.command` and `.tool_input.file_path // .tool_input.path`
- `hooks/feedback/post-write.sh` — parses `.tool_input.file_path // .tool_input.path`
- `hooks/feedback/post-bash.sh` — parses `.tool_input.command`

For each: verify jq fallback chain covers both CC and Kiro field names. Fix any gaps.

### Task 3: Evaluate agentSpawn hook

**Files:**
- Modify: `.kiro/agents/default.json` (if adding agentSpawn)

Kiro supports `agentSpawn` (fires once when agent activates). Evaluate whether `session-init.sh` (currently on userPromptSubmit) should also/instead run on agentSpawn. Decision criteria: does session-init need to run before the first user prompt?

### Task 4: Black-box verification in live Kiro session

Specific test commands to run in this session:

**4a: preToolUse block test** — attempt `fs_write` to `/tmp/kiro-hook-test.txt`:
```bash
# This should be blocked by block-outside-workspace.sh
```
Use the fs_write tool targeting `/tmp/kiro-hook-test.txt`. If blocked → preToolUse works. If not blocked → preToolUse is broken.

**4b: preToolUse allow test** — write a file inside workspace:
```bash
# This should be allowed
```
Use fs_write to create `tests/hooks/.kiro-test-marker`. If succeeds → allow path works.

**4c: postToolUse test** — after writing a .sh file, check if post-write fires (look for lint/test output in hook stderr).

**4d: stop hook test** — complete a turn and check if verify-completion fires.

### Task 5: Build compatibility matrix and update README

**Files:**
- Create: `docs/kiro-hook-compatibility.md`
- Modify: `README.md`

Compatibility matrix format:

| Hook | CC | Kiro | Kiro Live Test | Notes |
|------|-----|------|----------------|-------|

Update README Compatibility section to reflect actual Kiro hook support including agentSpawn.

## Review
<!-- Reviewer writes here -->

## Checklist

- [ ] Test harness exists and is valid bash | `bash -n tests/hooks/test-kiro-compat.sh`
- [ ] Test harness has ALLOW tests for all security hooks | `for hook in block-dangerous block-secrets block-sed-json block-outside-workspace; do grep -q "ALLOW.*$hook" tests/hooks/test-kiro-compat.sh || exit 1; done`
- [ ] Test harness covers all 12 wired hooks | `for hook in block-dangerous block-secrets block-sed-json block-outside-workspace pre-write enforce-ralph-loop correction-detect session-init context-enrichment post-write post-bash verify-completion; do grep -q "$hook" tests/hooks/test-kiro-compat.sh || exit 1; done`
- [ ] block-outside-workspace blocks external fs_write | `echo '{"hook_event_name":"preToolUse","cwd":"/tmp","tool_name":"fs_write","tool_input":{"command":"create","path":"/tmp/evil.txt","file_text":"x"}}' | bash hooks/security/block-outside-workspace.sh 2>&1; test $? -eq 2`
- [ ] block-outside-workspace allows internal fs_write | `echo '{"hook_event_name":"preToolUse","cwd":"'$(pwd)'","tool_name":"fs_write","tool_input":{"command":"create","path":"'$(pwd)'/tests/hooks/.marker","file_text":"x"}}' | bash hooks/security/block-outside-workspace.sh 2>&1; test $? -eq 0`
- [ ] block-dangerous blocks rm -rf | `echo '{"hook_event_name":"preToolUse","cwd":"/tmp","tool_name":"execute_bash","tool_input":{"command":"rm -rf /"}}' | bash hooks/security/block-dangerous.sh 2>&1; test $? -eq 2`
- [ ] block-dangerous allows safe command | `echo '{"hook_event_name":"preToolUse","cwd":"/tmp","tool_name":"execute_bash","tool_input":{"command":"ls -la"}}' | bash hooks/security/block-dangerous.sh 2>&1; test $? -eq 0`
- [ ] block-sed-json blocks sed on .json | `echo '{"hook_event_name":"preToolUse","cwd":"/tmp","tool_name":"execute_bash","tool_input":{"command":"sed -i s/old/new/ config.json"}}' | bash hooks/security/block-sed-json.sh 2>&1; test $? -eq 2`
- [ ] pre-write blocks CLAUDE.md write | `echo '{"hook_event_name":"preToolUse","cwd":"'$(pwd)'","tool_name":"fs_write","tool_input":{"command":"create","path":"'$(pwd)'/CLAUDE.md","file_text":"hijack"}}' | bash hooks/gate/pre-write.sh 2>&1; test $? -eq 2`
- [ ] All test harness tests pass | `bash tests/hooks/test-kiro-compat.sh 2>/dev/null | grep -c FAIL | grep -q '^0$'`
- [ ] Compatibility matrix doc exists | `test -f docs/kiro-hook-compatibility.md`
- [ ] README updated with Kiro hook details | `grep -q "agentSpawn" README.md`

## Errors

| Error | Task | Attempt | Resolution |
|-------|------|---------|------------|

## Findings

