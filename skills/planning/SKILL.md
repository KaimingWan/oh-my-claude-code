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

After plan is reviewed and approved, choose execution strategy:

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

1. Dispatch implementer subagent per task
2. Review after each task (spec compliance → code quality)
3. Fix issues before next task

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
