---
name: planning
description: "Write and execute implementation plans. Covers: plan writing, TDD task structure, execution strategies (sequential/parallel/subagent), and git worktree isolation."
---

# Planning — Write, Review, Execute

## Overview

One skill for the full plan lifecycle: write → review → execute.

## Phase 0: Deep Understanding

Before writing any plan, build deep understanding of the goal. Skip this phase only if the user provides a fully specified design doc.

### Step 1: Form Initial Understanding

Read relevant code, docs, and recent commits to understand the context. Do NOT ask questions yet — first build your own mental model of:
- What the user wants to achieve
- What exists today (current state)
- What would need to change (gap analysis)

### Step 2: Ask Clarifying Questions

Based on your understanding, ask questions **one at a time**. Each question must:
- Eliminate a whole branch of ambiguity (not trivial details)
- Build on previous answers (incremental deepening)
- Offer multiple-choice options with your recommendation when possible

**Dynamic termination:** Stop asking when remaining uncertainty won't materially affect the plan. Don't ask for the sake of asking.

**Soft cap:** Maximum 5 questions. If you still have uncertainty after 5, state your assumptions and proceed.

### Step 3: Research (optional)

After questions are answered, judge whether research is needed:
- **Codebase research:** When the task touches existing code you haven't fully explored (e.g., modifying a hook system — read existing hooks first)
- **Web research:** When the task involves external tools, APIs, or best practices you're unsure about (e.g., integrating a new library, adopting an unfamiliar pattern)
- **Both:** When the task combines internal changes with external dependencies (e.g., adding OAuth to an existing auth module)
- **Skip:** When you have sufficient understanding (e.g., renaming a variable, fixing a typo, simple refactors with clear scope)

**Research dimension principle:** When research IS needed, cover both theoretical foundations (papers, docs, design rationale) AND engineering practice (real implementations, battle-tested patterns, known pitfalls). One without the other leads to either ivory-tower designs or cargo-culted solutions.

This is your judgment call — not every plan needs research.

### Step 4: Supplementary Questions (if any)

After research, absorb what you learned. Only ask the user about findings you **cannot resolve from research alone** — things requiring user decisions or preferences.

If no supplementary questions needed, proceed directly to Phase 1.

### Transition to Phase 1

After Phase 0 completes, proceed to Phase 1 (Writing the Plan) with the accumulated understanding. All context gathered — user answers, research findings, codebase observations — feeds directly into plan writing.

### Error Handling

- **No relevant code/docs found:** Inform the user, ask them to point you to the right area, then continue.
- **User wants to skip Phase 0:** Allowed. User can say "skip questions" or "just write the plan" at any time. State your assumptions and proceed to Phase 1.
- **Contradictory answers:** Surface the contradiction to the user, ask them to clarify which direction to take.
- **5-question cap reached with critical ambiguity:** State remaining assumptions explicitly, proceed to Phase 1. The plan will note these assumptions for reviewer scrutiny.

## Phase 1: Writing the Plan

**Save to:** `docs/plans/YYYY-MM-DD-<feature-name>.md`

### Plan Header (required)

```markdown
# [Feature Name] Implementation Plan

**Goal:** [One sentence]
**Non-Goals:** [What this plan explicitly does NOT do]
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
- `- [ ] config 包含新 hook | \`jq '.hooks' .kiro/agents/pilot.json | grep -q my-hook\``
- `- [ ] 外部路径被拦截 | \`echo '{"tool_name":"fs_write","tool_input":{"file_path":"/tmp/evil.txt"}}' | bash hooks/security/my-hook.sh 2>&1; test $? -eq 2\``

Rules:
- verify command must be executable (no "手动测试", no "目视检查")
- verify command must return exit 0 on success
- Each Task must have at least 1 checklist item
- Cover: happy path + edge case + integration (where applicable)
- Hook enforces: checking off `- [x]` requires recent successful execution of the verify command
- **Regression test rule:** If plan Files fields include `scripts/ralph_loop.py` or `scripts/lib/`, the checklist MUST include: `- [ ] 回归测试通过 | \`python3 -m pytest tests/ralph-loop/ -v\``

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

### Errors Section (required)

Every plan must have an `## Errors` section at the bottom. During execution, log every error encountered:

```markdown
## Errors

| Error | Task | Attempt | Resolution |
|-------|------|---------|------------|
```

Rules:
- Log immediately when error occurs, don't wait
- Include which Task triggered the error
- Track attempt number — if same error appears at attempt 3, trigger 3-Strike Protocol (see Phase 2)
- This section is append-only during execution — never delete entries
- Cap: keep most recent 20 entries; if exceeded, summarize older entries into a single "Earlier errors: N resolved" row

### Findings Section (optional)

Plans may include a `## Findings` section for persisting research discoveries made during execution:

```markdown
## Findings

- [discovery with context]
```

Rules:
- Append-only — never rewrite, only add new entries
- Use when execution-phase research reveals something relevant to later tasks
- Not required for simple plans where no research happens during execution

## Phase 1.5: Plan Review

After writing the plan, run multi-perspective plan review before execution.

### Angle Pool

Two categories: **fixed** (every round) and **random** (sampled each round).

**Fixed angles (always included):**

| Angle | Mission | Output |
|-------|---------|--------|
| Goal Alignment | You MUST copy each table below and fill EVERY cell. Do NOT summarize or skip rows. If a table has N tasks, your output must have N rows. Missing rows = review REJECTED. Copy and fill this table for EVERY task:\n\n\| Task # \| Goal phrase served (quote exact words) \| If removed, which Goal phrase loses coverage? \|\n\|--------\|---------------------------------------\|----------------------------------------------\|\n\| 1 \| [quote] \| [answer] \|\n\nThen copy and fill the coverage matrix:\n\n\| Goal phrase (copy from plan header) \| Covered by Task #s \|\n\|-------------------------------------\|-------------------\|\n\| [phrase 1] \| [list] \|\n\nFinally: trace the execution order — does Task N's output feed correctly into Task N+1's input? Findings must cite specific Task numbers and Goal phrases. | Missing Coverage / Unnecessary Tasks / Ordering Issues / Verdict |
| Verify Correctness | For each checklist verify command, you MUST copy this table and fill in EVERY cell:\n\n\| # \| Verify command \| Confirms what \| Exit code (correct impl) \| Exit code (broken impl) \| Sound? \|\n\|---\|---------------\|---------------\|--------------------------|--------------------------|--------\|\n\| 1 \| [copy from plan] \| [fill] \| [trace: ... → exit ?] \| [trace: ... → exit ?] \| [Y/N + reason] \|\n\nRules: EVERY row must show the shell execution trace, not just "exit 0". If you skip a row or write "all sound" without per-row traces, your review is REJECTED. Only flag commands where correct and broken give the SAME exit code. | False Positives / Weak Verifications / Verdict |

**Random pool (2 sampled per round):**

| Angle | Mission | Analysis Method | Output |
|-------|---------|-----------------|--------|
| **All angles** | Before writing any finding, verify it is within the plan's stated Goal and NOT in Non-Goals. Findings outside scope are noise — discard silently. | — | — |
| Completeness | For each source file in the plan's Files fields: 1) list its public functions/branches, 2) check which are exercised by at least one Task, 3) flag functions/branches with zero coverage. Also: for each error path in source (try/except, if-error-return, signal handler), verify at least one Task exercises it. Findings must cite specific function names and line ranges. SCOPE: Only analyze functions/branches in files that the plan MODIFIES (listed in Files: fields). Do NOT flag functions in files the plan merely reads or references. The plan is not obligated to test every function in every file it touches — only the functions it changes. | Source-to-task traceability matrix | Uncovered Functions / Unexercised Error Paths / Verdict |
| Testability | For each Task's test cases: 1) identify the assertion (what property is checked), 2) construct a minimal wrong implementation that would still pass the assertion (false negative analysis), 3) flag tests where such a wrong implementation exists. Focus on: are assertions specific enough to catch real bugs, not just "no crash"? | False negative analysis per test | Weak Assertions / False Negative Risks / Verdict |
| Technical Feasibility | For each Task: 1) list external dependencies (libraries, OS features, file system assumptions), 2) check if any dependency has platform/version constraints that conflict with Tech Stack, 3) for subprocess-based tests, verify timeout values are sufficient for the operations described. Flag only concrete blockers, not theoretical risks. | Dependency + constraint audit | Blockers / Platform Risks / Verdict |
| Security | For each Task that touches file I/O, subprocess, or signal handling: 1) trace data flow from external input to execution, 2) check for path traversal, command injection, or symlink attacks in test fixtures, 3) verify temp files use secure creation (tmp_path, not hardcoded paths). | Data flow trace per Task | Injection Surfaces / Unsafe Patterns / Verdict |
| Compatibility & Rollback | For each modified file in the plan: 1) list existing tests that import or call functions in that file, 2) check if the plan's changes could break those existing tests, 3) verify the plan includes running existing tests (not just new ones). Also: can the plan's changes be reverted with a single `git revert`? | Existing-test impact analysis | Breaking Changes / Revert Safety / Verdict |
| Performance | For each Task involving subprocess or threading: 1) calculate worst-case wall-clock time (timeout × max_iterations × retry count), 2) sum across all Tasks to get total suite time, 3) flag any single test that could exceed 30s without @pytest.mark.slow. Provide concrete numbers, not estimates. | Quantified time budget per Task | Time Budget Table / Slow Test Violations / Verdict |
| Clarity | For each Task's "What to implement" section: 1) attempt to write the function signature and key assertions from the description alone (without reading source), 2) flag any Task where you cannot determine the exact test structure from the description. A clear plan = an executor agent can implement without reading source first. | Implementability dry-run | Ambiguous Tasks / Missing Specs / Verdict |

### Angle Selection

Every round: 2 fixed + 2 random = 4 reviewers (one parallel batch, no overflow).

Random selection: sample 2 from the random pool. Repeats across rounds are fine — the same angle reviewing a revised plan catches regressions and verifies fixes.

### Dispatch Query Template

Each reviewer query MUST include: Context (Goal, Non-Goals, key design decisions), Mission (angle-specific from table above), files to read, and anti-patterns.

```
## Context
Goal: [one sentence from plan header]
Non-Goals: [from plan header]
Key design decisions that reviewers might mistake for gaps:
- [decision 1 — what was chosen and what was intentionally excluded]
- [decision 2]

## Your Mission
This is a PLAN REVIEW (Mode 1 in your prompt).
[angle-specific mission from the table above]

## Read These Files
Plan: [path]
Source files referenced in plan: [list — reviewer must read before claiming code behavior]

## Anti-patterns (do NOT do these)
- Do not flag issues outside the stated Goal/Non-Goals
- Do not suggest alternative approaches that are equally valid
- Do not flag missing implementation details that an executor agent can infer
- [plan-specific anti-patterns if any]

## Mandatory Source Reading
Before making ANY claim about code behavior, you MUST:
1. Read the actual source file (use Bash: cat <file>)
2. Cite the specific line number in your finding
3. If you haven't read the file, do NOT speculate — read it first
Findings about code behavior without file:line citations will be discarded.
```

### Orchestration

1. Compose the round: Goal Alignment + Verify Correctness + 2 random angles
2. Dispatch 4 reviewer subagents in ONE `use_subagent` call. Each reviewer query = review angle mission + plan file path. Reviewer reads the file itself (has read/shell tools). Do NOT paste plan content into query — it bloats payload and breaks 4-way parallelism. **Must pass plan file path, not content.** **Must specify `agent_name: "reviewer"`**. Same `agent_name` can spawn multiple instances in parallel. **Include in each query:** "Read the source files referenced in the plan before making claims about code behavior."
4. Reviewers in the same round do NOT see each other's feedback
5. Collect all verdicts. If ANY reviewer REJECTs → fix issues → next round (re-sample 2 random angles)
6. **Round 2+ rule:** When re-dispatching after fixes, include in each query a "Rejected Findings" section with one-line summaries of findings rejected in previous rounds and why. Reviewers must not re-raise these.
7. Repeat until all APPROVE in a single round, or 5 rounds reached
8. After 5 rounds: stop and tell user "Plan too complex for automated review. Consider breaking into smaller plans."

### Reviewer Calibration

Reviewers should REJECT only for issues that would cause the plan to fail or produce wrong results. Do NOT reject for:
- Style preferences or alternative approaches that are equally valid
- Theoretical risks that are unlikely in practice
- Missing features that are nice-to-have but not required for the plan's stated goal

The bar is "would this plan produce a 90/100 result?" not "is this plan perfect?"

### Conflict Resolution

When reviewers give contradictory feedback:
1. Main agent compares both arguments against the plan's **Goal** statement (the one-sentence goal in the plan header)
2. The argument that directly serves the stated Goal wins
3. Document the conflict, both arguments, and the resolution in the plan's Review section
4. If both arguments equally serve the goal, ask the user to decide

### Resource Constraints

- **Max parallel subagents per batch**: 4 (tool hard limit). Fixed at 4 per round, no overflow batches needed.
- **Reviewer context isolation**: Reviewers in the same round do NOT see each other's feedback. Each gets the full plan.
- **Context size**: Review packet = full plan file content (verbatim). Reviewers need complete task details, code blocks, and file paths to avoid false rejections from incomplete information.
- **Error handling**: If a reviewer crashes or returns malformed output, continue with remaining reviewers. If fewer than half of the round's reviewers complete, restart the round. Malformed = missing Mission/Findings/Verdict structure.

## Phase 2: Execution

After plan is reviewed and approved, choose execution strategy based on checklist size:

### Execution Disciplines

These rules apply regardless of which execution strategy is chosen.

#### Session Resume Protocol

When starting or resuming execution (including new sessions):
1. Read the plan's Goal + Architecture + Non-Goals
2. Run `git diff --stat` to see what's already changed
3. Check checklist: which items are `[x]` done, which `[ ]` remain
4. Write a one-line status summary to the plan's `## Findings` section

This ensures the agent has full context before making any changes.

#### Read Before Decide

Before any of these actions, re-read the plan's **Goal** and **Non-Goals**:
- Changing implementation approach mid-task
- Deciding to skip or reorder a task
- Encountering a blocker and choosing a workaround
- Adding scope not in the original plan

This pushes the original intent back into the attention window, preventing drift after many tool calls.

#### Periodic Re-orientation

Every 3 completed tasks, re-read the plan's **Goal** paragraph. No writing needed — purely attention refresh. This counters gradual context decay in long execution sessions.

#### 3-Strike Error Protocol

When an error occurs during execution:

**Strike 1 — Diagnose & Fix:** Read error carefully, identify root cause, apply targeted fix. Log to `## Errors`.

**Strike 2 — Alternative Approach:** Same error? Try a fundamentally different method. Different tool, different algorithm, different angle. Log to `## Errors`.

**Strike 3 — Broader Rethink:** Question assumptions. Search for solutions. Consider whether the plan itself needs revision. Log to `## Errors`.

**After 3 strikes:** Stop and escalate to user. Explain what was tried, share the specific errors, ask for guidance. Do NOT attempt a 4th time with the same approach.

Rules:
- `next_action != failed_action` — never repeat the exact same failing approach
- Each strike must be logged in the plan's `## Errors` table with attempt number
- Strike count is per-error-type, not global (different errors get their own 3 strikes)

### Strategy Selection

| Checklist Items | Strategy | Rationale |
|----------------|----------|-----------|
| ≤3 | A: Sequential in main conversation | Low overhead, not worth subagent spawn cost |
| >3 | C: Subagent per task | Isolates context, prevents conversation bloat |
| 2+ independent tasks | B: Parallel agents | No shared state, can run simultaneously |
| 2+ tasks, non-overlapping files | D: Parallel Fan-out | Concurrent execution with zero race conditions |

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

1. Dispatch subagent per task. **Must specify `agent_name`** if using a custom executor agent, or ensure the built-in default subagent is allowed in `availableAgents`. Subagents inherit workspace MCP if `includeMcpJson: true`.
2. Review after each task (spec compliance → code quality)
3. Fix issues before next task

**Subagent capability limits (do NOT delegate tasks that need these):**
- `code` tool (LSP analysis, symbol search, goto_definition)
- `web_search` / `web_fetch` (internet access — use main agent instead, it's free)
- `use_aws` (AWS CLI)
- Cross-step context (subagents are stateless between invocations)

### Strategy D: Parallel Fan-out

**When:** 2+ independent tasks with non-overlapping file sets.

> **Note:** ralph_loop.py now auto-analyzes task dependencies and generates batch-aware prompts with explicit dispatch instructions. The agent no longer needs to judge independence — it receives pre-computed batches.

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
