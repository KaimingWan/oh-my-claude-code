# Planning Skill: Deep Understanding Before Writing

**Goal:** Improve planning skill Phase 1 by adding a "deep understanding" pre-phase — agent first understands the goal, then asks high-quality questions incrementally, then optionally researches, then writes the plan.

**Architecture:** Modify `skills/planning/SKILL.md` Phase 1 only. Insert a new "Phase 0: Deep Understanding" before the existing plan-writing step. No changes to Phase 2 (execution) or Phase 3 (completion).

**Tech Stack:** Markdown skill file only.

## Design

### Current Flow (Phase 1)
```
User gives goal → Agent writes plan immediately
```

### New Flow (Phase 0 + Phase 1)
```
User gives goal
  → Agent reads codebase/context to form initial understanding
  → Agent asks questions one-at-a-time (incremental, each builds on previous answers)
  → Agent judges: need research? (codebase / web / both / neither)
  → If researched: agent absorbs findings, only asks user truly unresolvable questions
  → Agent writes plan
```

### Key Principles

1. **Questions must eliminate whole branches of ambiguity** — no trivial or obvious questions
2. **One question at a time, incremental** — later questions build on earlier answers
3. **Dynamic termination** — stop when remaining uncertainty won't affect plan quality
4. **Soft cap of 5 questions** — safety net against infinite questioning loops
5. **Research is optional and auto-judged** — agent decides based on task nature (internal refactor → codebase only; new integration → web; pure logic change → skip)
6. **Research absorbs before asking** — only surface questions the agent truly cannot infer from research results

### What Changes

| Aspect | Before | After |
|--------|--------|-------|
| Phase 1 entry | Directly write plan | Phase 0 → then write plan |
| Question quality | N/A (no questions) | High — based on initial understanding |
| Research | N/A | Optional, auto-judged by task type |
| User burden | Low (but plan quality suffers) | Moderate (but plan quality improves) |

## Review

**Reviewer:** Kiro (subagent)

### Strengths
- Clear architectural decision to modify only Phase 1, preserving existing execution phases
- Well-defined principles with concrete constraints (5 question cap, dynamic termination)
- Comprehensive checklist with executable verification commands
- Good separation of concerns: understanding → questioning → research → planning
- Research is optional and agent-judged, avoiding unnecessary overhead

### Weaknesses
- **CRITICAL:** Missing integration with existing Phase 1 structure - plan doesn't address how Phase 0 transitions to current Phase 1 content
- **WARNING:** No fallback mechanism if agent gets stuck in questioning loop despite 5-question cap
- **WARNING:** Research step lacks concrete guidance on when to choose codebase vs web vs both
- Verification commands assume Phase 0 content will be exactly as specified, but don't verify the transition logic

### Missing
- Error handling: what if initial understanding step fails (no relevant code/docs found)?
- User experience consideration: how to handle impatient users who want to skip Phase 0?
- Integration testing: how to verify Phase 0 → Phase 1 flow works end-to-end?
- Rollback plan: how to revert if Phase 0 degrades planning quality?

### Edge Cases Not Addressed
- What if user provides contradictory answers to incremental questions?
- How to handle research that contradicts user's stated requirements?
- What if the 5-question cap is reached but critical ambiguity remains?

### Verdict: **REQUEST CHANGES**

**Required fixes:**
1. ~~Add explicit transition mechanism from Phase 0 to existing Phase 1 content~~ → DONE: Added "Transition to Phase 1" subsection
2. ~~Add error handling for failed initial understanding~~ → DONE: Added "Error Handling" subsection
3. ~~Add integration verification that tests the full Phase 0 → Phase 1 flow~~ → DONE: Added 3 new checklist items
4. ~~Clarify research decision criteria with concrete examples~~ → DONE: Added concrete examples to Step 3

**Recommended additions:**
- ~~User escape hatch for skipping Phase 0 when appropriate~~ → DONE: Added to Error Handling
- Rollback strategy if Phase 0 proves problematic in practice → DEFERRED: low risk, can be addressed via episodes.md if issues arise

---

**Round 2 Review (Kiro subagent)**

### Verification of Round 1 Fixes

**Fix 1: Transition mechanism** ✅ ADEQUATE
- Added "Transition to Phase 1" subsection with clear handoff description
- Explicitly states how Phase 0 context feeds into Phase 1 plan writing

**Fix 2: Error handling** ✅ ADEQUATE  
- Added comprehensive "Error Handling" subsection covering all 4 scenarios:
  - No docs found → ask user for direction
  - User skip → allowed with assumption stating
  - Contradictions → surface to user for clarification
  - Cap reached → state assumptions and proceed

**Fix 3: Integration verification** ✅ ADEQUATE
- Added 3 new checklist items (items 10-12):
  - Transition to Phase 1 documented
  - Error handling section present  
  - User skip escape hatch documented
- Total checklist now 12 items with proper verification commands

**Fix 4: Concrete research examples** ✅ ADEQUATE
- Step 3 now includes 4 concrete scenarios with specific examples:
  - Codebase: "modifying a hook system — read existing hooks first"
  - Web: "integrating a new library, adopting an unfamiliar pattern"
  - Both: "adding OAuth to an existing auth module"
  - Skip: "renaming a variable, fixing a typo, simple refactors"

### Strengths
- All 4 requested changes implemented comprehensively
- Error handling covers edge cases not originally considered
- Research examples are specific and actionable
- Checklist verification commands are executable and precise

### Weaknesses
- None identified — all critical gaps from Round 1 have been addressed

### Missing
- Nothing critical — plan is now complete and implementable

### Verdict: **APPROVE**

Plan is ready for implementation. All Round 1 concerns resolved with adequate detail and verification.

## Tasks

### Task 1: Add Phase 0 to planning SKILL.md

**Files:**
- Modify: `skills/planning/SKILL.md`

**Step 1: Write the new Phase 0 section**

Insert a new `## Phase 0: Deep Understanding` section before the existing `## Phase 1: Writing the Plan`. Content:

```markdown
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
```

**Step 2: Verify the change**

Run: `grep -c "Phase 0: Deep Understanding" skills/planning/SKILL.md`
Expected: 1

**Step 3: Verify Phase 1 reference is intact**

Run: `grep -c "Phase 1: Writing the Plan" skills/planning/SKILL.md`
Expected: 1

**Step 4: Commit**

```bash
git add skills/planning/SKILL.md
git commit -m "feat(planning): add Phase 0 deep understanding before plan writing"
```

## Checklist

- [x] Phase 0 section exists in SKILL.md | `grep -q "## Phase 0: Deep Understanding" skills/planning/SKILL.md`
- [x] Phase 0 appears before Phase 1 | `awk '/## Phase 0/{p0=NR} /## Phase 1/{p1=NR} END{exit (p0 < p1 ? 0 : 1)}' skills/planning/SKILL.md`
- [x] Step 1 (Form Initial Understanding) present | `grep -q "### Step 1: Form Initial Understanding" skills/planning/SKILL.md`
- [x] Step 2 (Ask Clarifying Questions) present | `grep -q "### Step 2: Ask Clarifying Questions" skills/planning/SKILL.md`
- [x] Step 3 (Research) present | `grep -q "### Step 3: Research" skills/planning/SKILL.md`
- [x] Step 4 (Supplementary Questions) present | `grep -q "### Step 4: Supplementary Questions" skills/planning/SKILL.md`
- [x] Dynamic termination principle documented | `grep -q "Dynamic termination" skills/planning/SKILL.md`
- [x] Soft cap of 5 documented | `grep -q "Maximum 5 questions" skills/planning/SKILL.md`
- [x] Existing Phase 1/2/3 unchanged | `grep -c "## Phase [123]" skills/planning/SKILL.md | grep -q "3"`
- [x] Transition to Phase 1 documented | `grep -q "### Transition to Phase 1" skills/planning/SKILL.md`
- [x] Error handling section present | `grep -q "### Error Handling" skills/planning/SKILL.md`
- [x] User skip escape hatch documented | `grep -q "skip questions" skills/planning/SKILL.md`
