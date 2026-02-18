# Claude Code Compatibility — Hooks Verification + Agent Adaptation

**Goal:** Verify all existing hooks work correctly in real Claude Code environment, and generate `.claude/agents/*.md` files from `generate_configs.py` so subagents (reviewer, researcher, executor) work in CC — without breaking any existing Kiro CLI functionality.

**Non-Goals:**
- Leveraging CC-only features (SessionStart, async hooks, prompt hooks, PermissionRequest, etc.)
- Changing hook behavior or adding new hooks
- Modifying Kiro agent JSON configs
- Supporting CC agent teams or persistent memory

**Architecture:** Extend `generate_configs.py` to output `.claude/agents/*.md` files (Markdown + YAML frontmatter) alongside existing outputs. Write a CC-format test script mirroring `test-kiro-compat.sh` but using CC tool names (`Bash`, `Write`, `Edit`) and field names (`file_path`, `content`). Provide a manual verification checklist for real CC testing.

**Tech Stack:** Python 3, Bash, jq, Claude Code CLI

## Tasks

### Task 1: CC-Format Hook Test Script

**Files:**
- Create: `tests/hooks/test-cc-compat.sh`

**Step 1: Write failing test**
Create test script that sends CC-format JSON (tool_name: `Bash`/`Write`/`Edit`, fields: `file_path`/`content`) to every hook and checks exit codes. Mirror the structure of `test-kiro-compat.sh` but with CC conventions.

**Step 2: Run test — verify it fails**
Run: `bash tests/hooks/test-cc-compat.sh`
Expected: Script exists and runs (may pass if hooks already handle CC format)

**Step 3: Write implementation**
The test script covers all 13 wired hooks with CC-format stdin:
- Security hooks: `Bash` tool name, CC field names
- Gate hooks: `Write`/`Edit` tool name, `file_path`/`content` fields
- Feedback hooks: CC-format `prompt` field
- Each hook gets BLOCK + ALLOW test pairs (where applicable)

**Step 4: Run test — verify it passes**
Run: `bash tests/hooks/test-cc-compat.sh`
Expected: All PASS

**Verify:** `bash tests/hooks/test-cc-compat.sh`

### Task 2: Generate `.claude/agents/*.md` from `generate_configs.py`

**Files:**
- Modify: `scripts/generate_configs.py`
- Create: `.claude/agents/reviewer.md` (generated)
- Create: `.claude/agents/researcher.md` (generated)
- Create: `.claude/agents/executor.md` (generated)

**Step 1: Write failing test**
Add test to `tests/test_generate_configs.py` that verifies:
- `.claude/agents/reviewer.md` is generated with correct YAML frontmatter
- `.claude/agents/researcher.md` is generated with correct YAML frontmatter
- `.claude/agents/executor.md` is generated with correct YAML frontmatter
- Each has: name, description, tools, model, hooks section
- Markdown body contains the agent prompt

**Step 2: Run test — verify it fails**
Run: `python3 -m pytest tests/test_generate_configs.py -v -k cc_agent`
Expected: FAIL (no CC agent generation yet)

**Step 3: Write implementation**
Add to `generate_configs.py`:
- A `render_cc_agent_md(config: dict, prompt: str) -> str` function that converts Kiro JSON agent config to CC Markdown frontmatter format
- Mapping: Kiro `execute_bash` → CC `Bash`, `fs_write` → CC `Write|Edit`, `read` → CC `Read`
- Hook commands: prefix with `"$CLAUDE_PROJECT_DIR"/` (CC convention)
- `toolsSettings.shell.deniedCommands` → not directly supported in CC agent frontmatter, but hooks handle this
- CC agent `tools` field uses CC tool names: `Read`, `Write`, `Edit`, `Bash`, `Grep`, `Glob`
- CC agent `disallowedTools` for restrictions
- Write `.claude/agents/{name}.md` for reviewer, researcher, executor
- Prompt body comes from `agents/{name}-prompt.md`

**Step 4: Run test — verify it passes**
Run: `python3 -m pytest tests/test_generate_configs.py -v -k cc_agent`
Expected: PASS

**Verify:** `python3 -m pytest tests/test_generate_configs.py -v -k cc_agent`

### Task 3: Validate Generated CC Agents Have Correct Hook Format

**Files:**
- Modify: `tests/test_generate_configs.py`

**Step 1: Write failing test**
Add test that validates the generated `.claude/agents/*.md` files have hooks in CC format:
- Hook commands use `"$CLAUDE_PROJECT_DIR"/hooks/...` prefix
- Matchers use CC tool names (`Bash`, `Write|Edit`)
- YAML frontmatter is valid and parseable

**Step 2: Run test — verify it fails**
Run: `python3 -m pytest tests/test_generate_configs.py -v -k cc_hook_format`
Expected: FAIL

**Step 3: Write implementation**
Add YAML frontmatter parsing validation to the test.

**Step 4: Run test — verify it passes**
Run: `python3 -m pytest tests/test_generate_configs.py -v -k cc_hook_format`
Expected: PASS

**Verify:** `python3 -m pytest tests/test_generate_configs.py -v -k cc_hook_format`

### Task 4: Kiro Regression — Ensure Existing Outputs Unchanged

**Files:**
- (no new files — regression check only)

**Step 1: Snapshot current outputs**
Save current `.claude/settings.json` and `.kiro/agents/*.json` content.

**Step 2: Run generator**
Run: `python3 scripts/generate_configs.py`

**Step 3: Verify no regression**
Diff current outputs against snapshots. All Kiro configs and `.claude/settings.json` must be byte-identical.

**Step 4: Run existing tests**
Run: `bash tests/hooks/test-kiro-compat.sh`
Expected: All PASS (no regression)

**Verify:** `bash tests/hooks/test-kiro-compat.sh && python3 -m pytest tests/test_generate_configs.py -v`

### Task 5: Automated CC Integration Test Script

**Files:**
- Create: `tests/hooks/test-cc-integration.sh`

**Step 1: Write test script**
Create a script that uses `claude -p` (print mode) with `--output-format json` to run real CC sessions and verify the full framework capability stack works in CC.

The script must:
- Check `claude --version` and login status; skip with clear message if not logged in
- Use `claude -p "prompt" --output-format json` for each test
- Parse JSON output to verify expected behavior
- Report PASS/FAIL/SKIP per test with summary

**Test categories and cases:**

**A. Security Hooks (PreToolUse block)**
1. block-dangerous: prompt CC to run `rm -rf /` → expect block message in output
2. block-secrets: prompt CC to echo an AWS key → expect block
3. block-sed-json: prompt CC to `sed -i` on a .json file → expect block
4. block-outside-workspace: prompt CC to write to `/tmp/evil.txt` → expect block

**B. Gate Hooks (PreToolUse block)**
5. pre-write instruction guard: prompt CC to overwrite CLAUDE.md → expect block
6. pre-write plan gate: prompt CC to create a new .py source file (no plan active) → expect block or plan reminder
7. enforce-ralph-loop: with .active plan + unchecked items, prompt CC to run a non-allowlisted command → expect block

**C. Feedback Hooks (UserPromptSubmit context injection)**
8. session-init: first prompt in session → verify rules injection fires (check output for 📚 or rules content)
9. context-enrichment research detect: prompt with "调研一下 X" → verify 🔍 research reminder in output
10. context-enrichment resume: with .completion-criteria.md having unchecked items → verify ⚠️ unfinished task reminder
11. correction-detect: prompt with "你错了，不要用 X" → verify correction detection fires (🚨 or 📝)

**D. Feedback Hooks (PostToolUse / Stop)**
12. post-bash verify log: prompt CC to run `echo hello` → verify /tmp/verify-log-*.jsonl gets an entry
13. post-write progress remind: prompt CC to edit a source file with active plan → verify 📝 reminder
14. verify-completion stop hook: prompt CC with a simple task → on completion, verify checklist check runs

**E. Subagent System**
15. agent discovery: run `claude -p "list available agents" --output-format json` → verify reviewer/researcher/executor mentioned
16. reviewer subagent: prompt CC to review current git diff using reviewer agent → verify it produces structured review output
17. researcher subagent: prompt CC to research a topic using researcher agent → verify it produces cited findings

**F. Skill System**
18. skill discovery: prompt CC "what skills are available?" → verify it finds skills from .claude/skills/ symlink
19. brainstorming skill trigger: prompt CC with "@plan build a feature" → verify brainstorming flow initiates (asks questions)
20. research skill trigger: prompt CC with "@research what is X" → verify research skill loads

**G. Command System**
21. @plan command: verify CC recognizes /plan or @plan command and loads the plan workflow
22. @review command: verify CC recognizes review command and dispatches reviewer
23. @reflect command: verify CC recognizes reflect command and offers to capture insight

**H. Knowledge System**
24. knowledge retrieval: prompt CC "have we seen this before?" → verify it checks episodes.md
25. rules injection: verify session-init injects relevant rules from knowledge/rules.md based on prompt keywords

**I. Plan Lifecycle (end-to-end)**
26. plan structure enforcement: prompt CC to write a plan missing ## Checklist → verify pre-write blocks it
27. checklist verify enforcement: prompt CC to check off a checklist item without running verify command → verify block

**Verify:** `bash tests/hooks/test-cc-integration.sh`

## Review

### Round 1 (4 reviewers, 2026-02-18)

**Angles:** Goal Alignment, Verify Correctness, Completeness, Compatibility & Rollback

**Goal Alignment:** APPROVE — all 4 goal phrases covered by tasks, execution flow correct (T1→T2→T3→T4→T5 dependencies valid).

**Verify Correctness:** APPROVE — all 6 verify commands produce distinct exit codes for correct vs broken implementations. Commands 1-5 correctly fail pre-implementation (TDD approach). Command 6 (`--validate`) already passes.

**Completeness:** APPROVE with note — `render_cc_agent_md()` function coverage is provided by Tasks 2+3 tests (`cc_agent` and `cc_hook_format` markers). Tool mapping and hook prefixing are validated through output assertions on generated files.

**Compatibility & Rollback:** APPROVE — all changes additive, existing Kiro configs verified byte-identical (Task 4), single `git revert` safe.

**Verdict: APPROVE** (4/4 reviewers)

## Checklist

- [ ] CC-format hook tests all pass | `bash tests/hooks/test-cc-compat.sh`
- [ ] CC agent .md files generated correctly | `python3 -m pytest tests/test_generate_configs.py -v -k cc_agent`
- [ ] CC agent hooks use correct format | `python3 -m pytest tests/test_generate_configs.py -v -k cc_hook_format`
- [ ] Kiro configs unchanged after regeneration | `bash tests/hooks/test-kiro-compat.sh && python3 -m pytest tests/test_generate_configs.py -v`
- [ ] CC integration tests pass (or skip if not logged in) | `bash tests/hooks/test-cc-integration.sh`
- [ ] generate_configs.py validation passes | `python3 scripts/generate_configs.py --validate`

## Errors

| Error | Task | Attempt | Resolution |
|-------|------|---------|------------|
