You MUST follow this exact sequence. Do NOT skip or reorder any step.

## Step 1: Brainstorming (skill: brainstorming)
Read .kiro/skills/brainstorming/SKILL.md, then use it to explore the user's intent, requirements, and constraints. Ask clarifying questions. Do NOT proceed until the user confirms the direction.

## Step 2: Writing Plan (skill: writing-plans)
Read .kiro/skills/writing-plans/SKILL.md, then write a plan to docs/plans/<date>-<slug>.md. The plan MUST include: Goal, Steps, and an empty ## Review section.

## Step 3: Reviewer Challenge (subagent: reviewer)
Dispatch a reviewer subagent (agent_name: "reviewer") with this query:

"Review the plan at docs/plans/<filename>. Find gaps, risks, missing steps, and edge cases. Be adversarial — assume the plan has flaws. Output: Strengths / Weaknesses / Missing / Verdict (APPROVE or REQUEST CHANGES with required fixes). Write your review into the plan's ## Review section."

## Step 4: Address Feedback
If reviewer verdict is REQUEST CHANGES or REJECT:
  - Fix the plan based on reviewer feedback
  - Mark old decisions as ~~deprecated~~ with reason
  - Re-dispatch reviewer for a second round
  - Repeat until APPROVE

## Step 5: User Confirmation
Show me the final plan with reviewer verdict. Ask me to confirm before any implementation.

## Step 6: Execute (skill: executing-plans)
Only after my explicit confirmation: read .kiro/skills/executing-plans/SKILL.md, then execute the approved plan.

---
User's requirement:
