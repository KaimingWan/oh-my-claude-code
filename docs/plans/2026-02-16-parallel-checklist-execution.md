# Parallel Checklist Execution

**Goal:** Enable concurrent execution of independent checklist tasks during @execute phase via fan-out/fan-in subagent pattern, with zero race conditions.
**Non-Goals:** Not implementing git worktree isolation for parallel tasks; not supporting parallel execution of tasks with overlapping files; not changing ralph-loop.sh bash script logic (only the prompt it sends).
**Architecture:** Create executor agent JSON with appropriate hooks → add Strategy D (Parallel Fan-out) to planning SKILL.md → update ralph-loop.sh prompt to enable parallel dispatch → fix config generator to include enforce-ralph-loop.sh → fix enforce-ralph-loop.sh to allow executor subagents.
**Tech Stack:** Bash, JSON, Markdown

## Review

### Round 1 (Completeness / Testability / Technical Feasibility / Clarity)
- **Completeness**: REQUEST CHANGES — missing rollback strategy, subagent failure handling, verify log integration → ✅ Fixed: added fallback rules, verify log integration checklist item
- **Testability**: REQUEST CHANGES — no verify log integration test, weak string matching → ✅ Fixed: added integration verify command, strengthened grep patterns
- **Technical Feasibility**: REQUEST CHANGES — atomic append concerns, test order → ✅ Fixed: documented PIPE_BUF safety in Findings, clarified task order
- **Clarity**: REJECT — tasks lack complete code blocks for autonomous execution → ✅ Fixed: all tasks now include exact code/content to write

### Round 2 (Completeness / Testability / Compatibility & Rollback / Performance)
- **Completeness**: APPROVE
- **Testability**: REQUEST CHANGES — deniedCommands verify too weak → ✅ Fixed: verify now checks actual "git commit" pattern in deniedCommands
- **Compatibility & Rollback**: APPROVE — all changes additive, fully reversible
- **Performance**: APPROVE — parallel benefits outweigh overhead

**Final status:** All reviewers APPROVE (Testability fix applied). Plan ready for user confirmation.

## Tasks

### Task 1: Create Executor Agent JSON + Config Generator

**Files:**
- Create: `.kiro/agents/executor.json`
- Modify: `scripts/generate-platform-configs.sh`

**Step 1: Create `.kiro/agents/executor.json`**

```json
{
  "name": "executor",
  "description": "Task executor for parallel plan execution. Implements code + runs verify. Does NOT edit plan files or git commit.",
  "tools": ["read", "write", "shell"],
  "allowedTools": ["read", "write", "shell"],
  "hooks": {
    "agentSpawn": [
      {
        "command": "echo '⚡ EXECUTOR: 1) Implement assigned task 2) Run verify command 3) Report result 4) Do NOT git commit or edit plan files'"
      }
    ],
    "preToolUse": [
      {"matcher": "execute_bash", "command": "hooks/security/block-dangerous.sh"},
      {"matcher": "execute_bash", "command": "hooks/security/block-secrets.sh"},
      {"matcher": "execute_bash", "command": "hooks/security/block-sed-json.sh"},
      {"matcher": "execute_bash", "command": "hooks/security/block-outside-workspace.sh"},
      {"matcher": "fs_write", "command": "hooks/security/block-outside-workspace.sh"}
    ],
    "postToolUse": [
      {"matcher": "execute_bash", "command": "hooks/feedback/post-bash.sh"}
    ]
  },
  "includeMcpJson": true,
  "toolsSettings": {
    "shell": {
      "autoAllowReadonly": true,
      "deniedCommands": [
        "git commit.*",
        "git push.*",
        "git checkout.*",
        "git reset.*",
        "git stash.*"
      ]
    }
  }
}
```

**Step 2: Add executor generation to `scripts/generate-platform-configs.sh`**

Insert after the researcher agent block (before the validation section), add:

```bash
# --- executor agent ---
jq -n '{
  name: "executor",
  description: "Task executor for parallel plan execution. Implements code + runs verify. Does NOT edit plan files or git commit.",
  tools: ["read", "write", "shell"],
  allowedTools: ["read", "write", "shell"],
  hooks: {
    agentSpawn: [{command: "echo '\''⚡ EXECUTOR: 1) Implement assigned task 2) Run verify command 3) Report result 4) Do NOT git commit or edit plan files'\''"}],
    preToolUse: [
      {matcher: "execute_bash", command: "hooks/security/block-dangerous.sh"},
      {matcher: "execute_bash", command: "hooks/security/block-secrets.sh"},
      {matcher: "execute_bash", command: "hooks/security/block-sed-json.sh"},
      {matcher: "execute_bash", command: "hooks/security/block-outside-workspace.sh"},
      {matcher: "fs_write", command: "hooks/security/block-outside-workspace.sh"}
    ],
    postToolUse: [{matcher: "execute_bash", command: "hooks/feedback/post-bash.sh"}]
  },
  includeMcpJson: true,
  toolsSettings: {
    shell: {
      autoAllowReadonly: true,
      deniedCommands: ["git commit.*", "git push.*", "git checkout.*", "git reset.*", "git stash.*"]
    }
  }
}' > .kiro/agents/executor.json

echo "  ✅ .kiro/agents/executor.json"
```

**Verify:** `jq -e '.name == "executor" and (.hooks.postToolUse | length > 0) and .includeMcpJson == true' .kiro/agents/executor.json`

### Task 2: Register Executor + Fix enforce-ralph-loop in Config Generator

**Files:**
- Modify: `scripts/generate-platform-configs.sh`

**Step 1: In the default agent section of `generate-platform-configs.sh`, modify `toolsSettings.subagent`:**

Change:
```
availableAgents: ["researcher", "reviewer"],
trustedAgents: ["researcher", "reviewer"]
```
To:
```
availableAgents: ["researcher", "reviewer", "executor"],
trustedAgents: ["researcher", "reviewer", "executor"]
```

**Step 2: In the default agent section, add enforce-ralph-loop.sh to preToolUse hooks:**

After the `fs_write` + `pre-write.sh` entry, add:
```
{matcher: "execute_bash", command: "hooks/gate/enforce-ralph-loop.sh"},
{matcher: "fs_write", command: "hooks/gate/enforce-ralph-loop.sh"}
```

**Step 3: Regenerate all configs:**
```bash
bash scripts/generate-platform-configs.sh
```

**Verify:** `jq -e '.toolsSettings.subagent.availableAgents | index("executor")' .kiro/agents/default.json && grep -q 'enforce-ralph-loop' scripts/generate-platform-configs.sh`

### Task 3: Add Subagent Compatibility Comment to enforce-ralph-loop.sh

**Files:**
- Modify: `hooks/gate/enforce-ralph-loop.sh`

**What to do:**

The current logic at line 36-42 already allows any process when ralph-loop PID is alive:
```bash
if [ -f "$LOCK_FILE" ]; then
  LOCK_PID=$(cat "$LOCK_FILE" 2>/dev/null | tr -d '[:space:]')
  if [ -n "$LOCK_PID" ] && kill -0 "$LOCK_PID" 2>/dev/null; then
    exit 0
  fi
```

Add a comment before `exit 0` explaining this is intentional:
```bash
    # Intentional: allows ANY process (including executor subagents) when ralph-loop is alive.
    # kill -0 checks if ralph-loop PID exists, not if current process IS ralph-loop.
    exit 0
```

**Verify:** `grep -q 'subagent' hooks/gate/enforce-ralph-loop.sh`

### Task 4: Add Strategy D to Planning SKILL.md

**Files:**
- Modify: `skills/planning/SKILL.md`

**Step 1: Update Strategy Selection table.** Change:

```markdown
| Checklist Items | Strategy | Rationale |
|----------------|----------|-----------|
| ≤3 | A: Sequential in main conversation | Low overhead, not worth subagent spawn cost |
| >3 | C: Subagent per task | Isolates context, prevents conversation bloat |
| 2+ independent tasks | B: Parallel agents | No shared state, can run simultaneously |
```

To:

```markdown
| Checklist Items | Strategy | Rationale |
|----------------|----------|-----------|
| ≤3 | A: Sequential in main conversation | Low overhead, not worth subagent spawn cost |
| >3 | C: Subagent per task | Isolates context, prevents conversation bloat |
| 2+ independent tasks | B: Parallel agents | No shared state, can run simultaneously |
| 2+ tasks, non-overlapping files | D: Parallel Fan-out | Concurrent execution with zero race conditions |
```

**Step 2: Add Strategy D section after Strategy C (before "### Workspace Isolation"):**

```markdown
### Strategy D: Parallel Fan-out

**When:** 2+ independent tasks with non-overlapping file sets.

**Independence check:** Extract `Files:` field from each Task. Two tasks are independent iff their file sets (Create + Modify + Test) have zero intersection. Tasks needing `code` tool (LSP) cannot be parallelized (subagents lack LSP).

**Execution flow:**

1. Identify all unchecked tasks, extract file sets from `Files:` field
2. Build independence graph: tasks with no file overlap form parallel groups
3. Group into batches (max 4 per batch — `use_subagent` hard limit)
4. For each batch, dispatch executor subagents in ONE `use_subagent` call:
   - `agent_name: "executor"` (must specify — see subagent rules)
   - Each subagent receives: full task description, file list, verify commands
   - Subagent contract: implement code + run verify command + report structured result
   - Subagent MUST NOT: edit plan file, git commit, modify files outside its task scope
5. Main agent collects results, validates each:
   - Re-run verify commands to confirm (trust but verify)
   - If any subagent failed: log to `## Errors`, fall back to Strategy A for that task
6. Main agent updates plan (check off completed items in one write)
7. Main agent does single `git add + commit` for the batch
8. Append to progress.md

**Fallback:** If parallel execution fails (subagent crash, verify failure), revert to Strategy A for remaining tasks in that batch. Never retry a failed parallel task in parallel — go sequential.

**Race condition prevention:**
- Plan file: only main agent writes (subagents never touch it)
- Git operations: only main agent commits (executor shell denies git commit)
- Verify log (`/tmp/verify-log-*.jsonl`): safe for concurrent append (entries <512 bytes, within POSIX PIPE_BUF)
- Source files: guaranteed non-overlapping by independence check
```

**Verify:** `grep -q 'Strategy D: Parallel Fan-out' skills/planning/SKILL.md && sed -n '/Strategy Selection/,/^### Strategy A/p' skills/planning/SKILL.md | grep -q 'Fan-out'`

### Task 5: Update Ralph-loop.sh Prompt

**Files:**
- Modify: `scripts/ralph-loop.sh`

**Step 1: Change `head -3` to `head -5` in NEXT_ITEMS assignment:**

Change:
```bash
NEXT_ITEMS=$(grep '^\- \[ \]' "$PLAN_FILE" | head -3)
```
To:
```bash
NEXT_ITEMS=$(grep '^\- \[ \]' "$PLAN_FILE" | head -5)
```

**Step 2: Add rule 8 to the PROMPT string, after rule 8 (the security hook rule):**

Add this line to the PROMPT:
```
9. PARALLEL EXECUTION: If 2+ unchecked items have non-overlapping file sets (check the plan's Task Files: fields),
   dispatch executor subagents in parallel (max 4, agent_name: "executor").
   Subagents only implement + run verify. YOU handle: plan file updates, git commit, progress.md.
   If any subagent fails, fall back to sequential for that item. See Strategy D in planning SKILL.md.
```

**Verify:** `grep -q 'executor' scripts/ralph-loop.sh && grep -q 'head -5' scripts/ralph-loop.sh`

### Task 6: Update Subagent Rules Documentation

**Files:**
- Modify: `.claude/rules/subagent.md`

**What to do:** Append after rule 3:

```
4. executor subagent 用于 plan task 并行执行。必须指定 agent_name: "executor"。executor 只做实现+验证，不改 plan 文件，不 git commit。主 agent 统一收尾（更新 plan、commit、progress）。verify log 由 executor 的 post-bash.sh hook 写入，主 agent 勾选 checklist 时 gate_checklist 能找到记录。
```

**Verify:** `grep -q 'executor.*plan.*commit' .claude/rules/subagent.md`

## Checklist

- [x] executor.json 存在且结构完整 | `jq -e '.name == "executor" and (.hooks.postToolUse | length > 0) and .includeMcpJson == true and (.toolsSettings.shell.deniedCommands | any(test("git commit")))' .kiro/agents/executor.json`
- [x] executor 在 config generator 中 | `grep -c 'executor' scripts/generate-platform-configs.sh | xargs test 2 -le`
- [x] executor 在 availableAgents 中 | `jq -e '.toolsSettings.subagent.availableAgents | index("executor")' .kiro/agents/default.json`
- [x] executor 在 trustedAgents 中 | `jq -e '.toolsSettings.subagent.trustedAgents | index("executor")' .kiro/agents/default.json`
- [x] enforce-ralph-loop 在 config generator 中 | `grep -c 'enforce-ralph-loop' scripts/generate-platform-configs.sh | xargs test 1 -le`
- [x] enforce-ralph-loop 在 default.json preToolUse 中 | `jq -e '[.hooks.preToolUse[] | select(.command | contains("enforce-ralph-loop"))] | length == 2' .kiro/agents/default.json`
- [x] enforce-ralph-loop 有 subagent 兼容注释 | `grep -q 'subagent' hooks/gate/enforce-ralph-loop.sh`
- [ ] Strategy D 在 planning SKILL.md Phase 2 中 | `sed -n '/^## Phase 2/,/^## Phase 3/p' skills/planning/SKILL.md | grep -q 'Strategy D: Parallel Fan-out'`
- [ ] Strategy Selection 表包含 D | `sed -n '/Strategy Selection/,/^### Strategy A/p' skills/planning/SKILL.md | grep -q 'Fan-out'`
- [ ] ralph-loop prompt 包含 executor 并行指令 | `grep -q 'executor' scripts/ralph-loop.sh`
- [ ] ralph-loop NEXT_ITEMS 用 head -5 | `grep -q 'head -5' scripts/ralph-loop.sh`
- [ ] subagent.md 包含 executor 规则 | `grep -q 'executor.*plan.*commit' .claude/rules/subagent.md`
- [ ] 所有 agent JSON 语法正确 | `for f in .kiro/agents/*.json; do jq -e . "$f" > /dev/null || exit 1; done`

## Errors

| Error | Task | Attempt | Resolution |
|-------|------|---------|------------|

## Findings

- PIPE_BUF on macOS = 512 bytes (verified via `getconf PIPE_BUF /tmp`). Verify log entries ~124 bytes. Concurrent JSONL append tested safe with 4 writers × 50 entries = 200 lines, 0 corruption.
- enforce-ralph-loop.sh current logic already allows any process when ralph-loop PID is alive (kill -0 checks PID existence, not caller identity). No code change needed, only clarifying comment.
- Config drift bug: generate-platform-configs.sh is single source of truth. Manual JSON edits get overwritten on regeneration. All hook registrations must go through the generator script.
