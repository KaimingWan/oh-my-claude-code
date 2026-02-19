You MUST follow this exact sequence. Do NOT skip or reorder any step.

## Step 1: Deep Understanding (skill: planning Phase 0)
Follow skills/planning/SKILL.md Phase 0 to build deep understanding of the goal. Ask clarifying questions, research if needed, and present design for creative/architectural work. Do NOT proceed until the user confirms the direction. After user confirms: `touch .phase0-confirmed`

## Step 2: Writing Plan (skill: planning)
Read skills/planning/SKILL.md, then write a plan to docs/plans/<date>-<slug>.md. The plan MUST include: Goal, Steps with TDD structure, an empty ## Review section, and a ## Checklist section with all acceptance criteria as `- [ ]` items. The checklist is the contract — @execute will not proceed without it.

## Step 3: Verify Checklist Exists
Before dispatching reviewer, confirm the plan file contains a `## Checklist` section with at least one `- [ ]` item. If missing, add it NOW — do not proceed to review without it.

## Step 4: Plan Review (skill: planning)
Follow `skills/planning/SKILL.md` Phase 1.5 for plan review. Select review angles based on plan complexity, dispatch reviewer subagent(s), and apply calibration rules defined there.

## Step 5: Address Feedback
If reviewer verdict is REQUEST CHANGES or REJECT:
  - Fix the plan based on reviewer feedback
  - Mark old decisions as ~~deprecated~~ with reason
  - Re-dispatch reviewer for a second round
  - Repeat until APPROVE

## Step 6: User Confirmation
Show the final plan with reviewer verdict. Ask user to confirm before any implementation.

## Step 7: Hand Off to Execute
After user confirms:
1. Write the plan file path to `docs/plans/.active` (e.g., `echo "docs/plans/2026-02-14-feature-x.md" > docs/plans/.active`)
2. Clean up: `unlink .phase0-confirmed 2>/dev/null || true`
3. **Auto-commit plan artifacts** — ralph_loop.py requires a clean working tree. Only commit files the agent created/modified during this plan session (plan file, .active, any skill/prompt changes). Do NOT `git add -A` — user may have unrelated edits in progress. Use explicit file paths:
   ```
   git add docs/plans/<plan-file>.md docs/plans/.active [other files agent touched]
   git commit -m "plan: <plan-slug> (reviewed, approved)"
   ```
   If `git status --porcelain` still shows untracked/modified files after this commit, warn the user: "You have uncommitted changes outside this plan. Stash or commit them before @execute."
4. Tell the user to run `@execute` to start implementation with Ralph Loop discipline (no unnecessary stops, one task at a time, commit after each).

---
User's requirement:
(If no requirement provided below, ask the user what they want to plan before proceeding.)
