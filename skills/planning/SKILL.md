---
name: planning
description: "Write and execute implementation plans. Covers: plan writing, TDD task structure, execution strategies (sequential/parallel/subagent), and git worktree isolation."
---

# Planning — Write, Review, Execute

## Overview

One skill for the full plan lifecycle: write → review → execute.

## Phase 1: Writing the Plan

**Save to:** `docs/plans/YYYY-MM-DD-<feature-name>.md`

### Plan Header (required)

```markdown
# [Feature Name] Implementation Plan

**Goal:** [One sentence]
**Architecture:** [2-3 sentences]
**Tech Stack:** [Key technologies]

## Review
<!-- Reviewer writes here -->
```

### Checklist Format (enforced by hook)

Every plan must have a `## Checklist` section. Every checklist item MUST include an executable verify command:

```markdown
- [ ] description | `verify command`
```

Examples:
- `- [ ] hook 语法正确 | \`bash -n hooks/security/my-hook.sh\``
- `- [ ] config 包含新 hook | \`jq '.hooks' .kiro/agents/default.json | grep -q my-hook\``
- `- [ ] 外部路径被拦截 | \`echo '{"tool_name":"fs_write","tool_input":{"file_path":"/tmp/evil.txt"}}' | bash hooks/security/my-hook.sh 2>&1; test $? -eq 2\``

Rules:
- verify command must be executable (no "手动测试", no "目视检查")
- verify command must return exit 0 on success
- Each Task must have at least 1 checklist item
- Cover: happy path + edge case + integration (where applicable)
- Hook enforces: checking off `- [x]` requires recent successful execution of the verify command

### Task Structure (TDD)

Each task follows red-green-refactor:

```markdown
### Task N: [Component Name]

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py`
- Test: `tests/exact/path/to/test.py`

**Step 1: Write failing test**
[Complete test code]

**Step 2: Run test — verify it fails**
Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL

**Step 3: Write minimal implementation**
[Complete implementation code]

**Step 4: Run test — verify it passes**
Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS

**Step 5: Commit**
```

Rules: exact file paths, complete code (not "add validation"), exact commands with expected output.

## Phase 2: Execution

After plan is reviewed and approved, choose execution strategy based on checklist size:

| Checklist Items | Strategy | Rationale |
|----------------|----------|-----------|
| ≤3 | A: Sequential in main conversation | Low overhead, not worth subagent spawn cost |
| >3 | C: Subagent per task | Isolates context, prevents conversation bloat |
| 2+ independent tasks | B: Parallel agents | No shared state, can run simultaneously |

### Strategy A: Sequential (default)

Execute tasks in order, 3-task batches with review checkpoints.

1. Load plan, create TodoWrite
2. Execute batch (3 tasks)
3. Report: what was done + verification output
4. Get feedback, apply changes
5. Next batch. Repeat until done.

### Strategy B: Parallel Agents

**When:** 2+ independent tasks, no shared state.

Dispatch one agent per independent domain:
- Each agent gets: specific scope + clear goal
- Don't use when: tasks are related, shared state, agents would interfere

### Strategy C: Subagent per Task

**When:** Tasks are independent, want fresh context per task.

1. Dispatch default subagent per task（自动继承 workspace ripgrep MCP）
2. Review after each task (spec compliance → code quality)
3. Fix issues before next task

**Subagent capability limits (do NOT delegate tasks that need these):**
- `code` tool (LSP analysis, symbol search, goto_definition)
- `web_search` / `web_fetch` (internet access — use main agent instead, it's free)
- `use_aws` (AWS CLI)
- Cross-step context (subagents are stateless between invocations)

### Workspace Isolation (Git Worktrees)

For non-trivial plans, create isolated workspace:

```bash
# Check for existing worktree dir
ls -d .worktrees 2>/dev/null || mkdir -p .worktrees

# Verify it's gitignored
git check-ignore -q .worktrees 2>/dev/null || echo '.worktrees' >> .gitignore

# Create worktree
git worktree add .worktrees/<feature-name> -b <feature-branch>
```

## Phase 3: Completion

After all tasks done:
1. Run full test suite
2. Present options: merge locally / create PR / keep branch / discard
3. Clean up worktree if applicable

## When to Stop and Ask

- Hit a blocker (missing dependency, unclear instruction)
- Verification fails repeatedly
- Plan has critical gaps
- Don't force through blockers — stop and ask.
