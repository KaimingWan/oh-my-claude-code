# Adversarial Multi-Perspective Plan Review

**Goal:** Replace the current 2-round rubber-stamp plan review with a multi-perspective, multi-round adversarial review system that uses 3-7 parallel reviewer subagents per round, rotating angles each round, with a 5-round hard cap.

**Architecture:** Modify two files: `skills/reviewing/SKILL.md` (single reviewer behavior with angle-specific mission/output) and `skills/planning/SKILL.md` (multi-angle orchestration logic in a new review phase). Also update Phase 0 Step 3 with the research dimension principle.

**Tech Stack:** Markdown skill files only.

## Design

### Current Flow
```
Plan written → 1 reviewer subagent → fix → 1 reviewer subagent → APPROVE (2 rounds, rubber stamp)
```

### New Flow
```
Plan written
  → Agent assesses plan complexity (by file count, scope, risk) → selects 3-7 angles from angle pool
  → Dispatches N reviewer subagents in parallel batches of 4 = Round 1
  → Any REJECT? → fix → select NEW angles (different from previous round, can reuse older rounds) → Round 2
  → Repeat until all APPROVE in a single round, or 5-round hard cap
  → 5 rounds exceeded → stop, tell user: "Plan needs to be broken into smaller plans or requirements clarified"
```

### Angle Pool

Each angle has a mission and required output format:

| Angle | Mission | Output |
|-------|---------|--------|
| Technical Feasibility | Can this be built? API limits, dependency risks, integration complexity | Risks / Blockers / Verdict |
| Completeness | Missing steps, unhandled edge cases, gaps in coverage | Missing Items / Edge Cases / Verdict |
| Over-engineering (YAGNI) | Is anything unnecessary? Could scope be reduced? | Unnecessary Items / Simplification Suggestions / Verdict |
| Security | Auth, data exposure, injection surfaces, secrets handling | Findings by Category / Severity / Verdict |
| Testability | Are checklist verify commands adequate? Can failures be detected? | Weak Verifications / Suggested Improvements / Verdict |
| Compatibility | Does this break existing behavior? Migration risks? | Breaking Changes / Migration Risks / Verdict |
| Rollback Safety | What if this fails in practice? Can it be reverted? | Failure Modes / Rollback Strategy / Verdict |
| Performance | N+1 calls, expensive loops, context window bloat | Bottlenecks / Recommendations / Verdict |
| Clarity | Is the plan unambiguous? Could another agent execute it without questions? | Ambiguous Sections / Rewording Suggestions / Verdict |

Agent selects 3-7 angles based on plan characteristics. Must explain why each angle was chosen.

### Angle Selection Guide

| Plan Characteristic | Recommended Angles | Count |
|--------------------|--------------------|-------|
| Single file, simple change | Completeness, Testability, Clarity | 3 |
| Multi-file, internal refactor | Completeness, Compatibility, Testability, Clarity | 4 |
| New feature, touches APIs/deps | Technical Feasibility, Completeness, Testability, Over-engineering, Compatibility | 5 |
| Security-sensitive (auth, hooks, permissions) | Security, Technical Feasibility, Completeness, Testability, Rollback Safety, Compatibility | 6 |
| Architecture change, multi-module | All relevant from pool, up to 7 | 7 |

Agent uses this as guidance, not rigid rules. Must explain angle choices.

### Conflict Resolution

When reviewers give contradictory feedback (e.g., YAGNI says "remove X" while Feasibility says "X is critical"):
1. Main agent compares both arguments against the plan's **Goal** statement (the one-sentence goal in the plan header)
2. The argument that directly serves the stated goal wins
3. Document the conflict, both arguments, and the resolution in the plan's Review section
4. If both arguments equally serve the goal, ask the user to decide

### Resource Constraints

- **Max parallel subagents per batch**: 4 (tool hard limit). If N > 4 angles, dispatch in batches of 4 then remainder.
- **Reviewer context isolation**: Reviewers in the same round do NOT see each other's feedback. Each gets only the review packet.
- **Context size**: Review packet = plan header (Goal/Architecture/Tech Stack) + full Checklist + 3-sentence context summary. Not the entire plan.
- **Error handling**: If a reviewer crashes or returns malformed output, continue with remaining reviewers. If fewer than half of the round's reviewers complete, restart the round. Malformed = missing Mission/Findings/Verdict structure.

### Key Rules

1. **Parallel execution**: All reviewers in a round run simultaneously as subagents, batched in groups of 4 (tool limit). If 5 angles selected, dispatch 4 then 1.
2. **Rotation**: Each new round must use different angles than the immediately previous round. Angles can be reused after skipping one round.
3. **Atomic rounds**: 1 REJECT in a round = entire round fails → fix → new round
4. **Hard cap**: 5 rounds max. Exceeding = stop and tell user "Plan too complex for automated review. Consider breaking into smaller plans."
5. **Review packet**: Each reviewer receives: plan Goal + Architecture (verbatim), full Checklist section, and a 3-sentence context summary written by the main agent. Not the entire plan.
6. **Structured output**: Every reviewer must output Mission / Findings / Verdict (APPROVE or REJECT with specific reasons)
7. **Error handling**: If a reviewer subagent crashes or returns malformed output, continue the round with remaining reviewers. If fewer than half complete, restart the round.

### Reviewer Calibration

Reviewers should REJECT only for issues that would cause the plan to fail or produce wrong results. Do NOT reject for:
- Style preferences or alternative approaches that are equally valid
- Theoretical risks that are unlikely in practice
- Missing features that are nice-to-have but not required for the plan's stated goal

The bar is "would this plan produce a 90/100 result?" not "is this plan perfect?"

### Research Dimension Principle (Phase 0 addition)

Add to Phase 0 Step 3: "Research should cover at least two dimensions: theoretical/academic AND engineering practice/best practices. Single-dimension research is incomplete."

## Review

### Round 1 - Clarity

**Mission:** Clarity

**Findings:**
- **"Agent assesses plan complexity"** - No criteria defined for complexity assessment. What makes a plan "simple" vs "architecture change"? Agent needs specific metrics or characteristics to evaluate.
- **"select NEW angles (no repeat)"** - Ambiguous scope. Does this mean no angle can be reused across ALL rounds, or just not repeated from the previous round? With 9 angles and up to 10 rounds, total prohibition is impossible.
- **"standard review packet"** - Format mentioned but not defined. What exactly is included in "plan + checklist + context summary"? How much context? Which sections of the plan?
- **"normal subagent limits"** - Undefined term. What are these limits? Timeout duration? Context size? Memory constraints?
- **"treat that angle as 'not reviewed'"** - Unclear consequence. Does this mean the round continues with fewer angles, or does the round fail and restart?
- **"redefine the problem"** - Vague instruction. What specific action should the agent take? Stop execution? Ask user for clarification? Provide specific guidance?
- **"Must explain angle choices"** - No format specified for explanations. Should this be documented in the plan? Logged? Presented to user?
- **"goal-aligned evaluation"** - Abstract concept without implementation guidance. How does the agent determine which argument is "more aligned with the goal"?

**Rewording Suggestions:**
- Replace "Agent assesses plan complexity" with specific criteria: "Agent counts modified files, checks for API changes, evaluates security implications using defined complexity matrix"
- Clarify angle rotation: "Each round must use different angles than the immediately previous round (angles can be reused after skipping one round)"
- Define review packet: "Review packet contains: plan summary (max 2000 chars), full checklist, and 3-sentence context summary"
- Specify limits: "Normal subagent limits: 5-minute timeout, 8000 token context window"
- Clarify error handling: "If reviewer crashes, continue round with remaining reviewers. If <50% complete, restart round."
- Define termination action: "After 10 rounds, stop execution and prompt user: 'Plan too complex for automated review. Consider breaking into smaller plans.'"

**Verdict:** REJECT

**Specific reasons:**
1. **Complexity assessment lacks criteria** - Agent cannot reliably categorize plans without defined metrics
2. **Angle rotation rule ambiguous** - Mathematical impossibility with current wording (9 angles, 10 rounds, no repeats)
3. **Multiple undefined terms** - "normal limits", "standard packet", "goal-aligned" need concrete definitions
4. **Missing implementation guidance** - Abstract concepts like "goal alignment" lack executable instructions

The plan requires concrete definitions and measurable criteria to be executable by another agent.

### Round 1 - Technical Feasibility

**Mission:** Technical Feasibility

**Findings:**
- **Subagent parallel dispatch limit exceeded**: Plan proposes 3-7 parallel reviewers per round, but context shows max 4 parallel subagents per call. With 7 angles, this requires batching which adds complexity not addressed in the design.
- **Reviewer subagent write capabilities confirmed**: Context confirms reviewer subagents can read and write files, so writing to specific plan sections is technically feasible.
- **Context window risk**: Each reviewer receives "plan + checklist + context summary" but no size limits defined. Large plans could exceed reviewer subagent context windows, causing failures.
- **Tool API limitations**: No timeout or error handling specified for crashed reviewer subagents. Plan mentions this in Resource Constraints but lacks implementation details.
- **Resource scaling concern**: Up to 70 subagent calls (7 angles × 10 rounds) could hit rate limits or performance bottlenecks not accounted for.
- **Angle selection algorithm dependency**: Plan requires "Agent selects 3-7 angles based on plan characteristics" but this logic must be implemented in the main agent, adding complexity.

**Verdict:** REJECT - Critical technical constraints not properly addressed

**Specific blockers:**
1. Parallel dispatch limit (4) vs proposed angles (up to 7) requires batching logic not designed
2. Context window constraints for large plans could cause reviewer failures
3. No concrete error handling for crashed subagents beyond "treat as not reviewed"

### Round 1 - Completeness

**Mission:** Find missing steps, unhandled edge cases, and gaps in coverage.

**Findings:**
- Missing error recovery for malformed reviewer output (what if subagent returns invalid format?)
- No handling for partial angle pool exhaustion (what if 8 rounds used 8 angles, only 1 left for round 9?)
- Undefined behavior when plan complexity changes mid-review (e.g., scope reduction after YAGNI feedback)
- Missing integration with existing `@review` command workflow
- No specification for reviewer context isolation (should reviewers see each other's feedback?)
- Undefined handling of reviewer subagent timeouts or crashes
- Missing validation that selected angles actually match plan characteristics
- No fallback when parallel subagent limit prevents full angle coverage
- Undefined behavior for plans that don't fit the complexity categories cleanly
- Missing specification of what constitutes "plan + checklist + context summary" size limits

**Verdict:** REJECT - Critical gaps in error handling and edge case coverage that could cause system failures in practice.

### Strengths
- Concrete checklist with verifiable acceptance criteria (✓ passes requirement #1)
- Well-researched design backed by academic papers (DReaMAD, D3 framework)
- Clear termination conditions prevent infinite loops (10-round hard cap)
- Angle rotation prevents bias reinforcement
- Structured output format ensures consistency

### Weaknesses
- **Complexity explosion**: 3-7 parallel subagents per round × up to 10 rounds = potentially 70 subagent calls for a single plan review. This could be prohibitively expensive and slow.
- **Angle selection logic undefined**: Plan says "Agent selects 3-7 angles based on plan characteristics" but provides no algorithm or criteria for this selection. How does the agent decide between 3 vs 7? Which angles for which plan types?
- **Conflict resolution missing**: What happens when reviewers from the same round give contradictory feedback? E.g., Over-engineering says "remove X" while Technical Feasibility says "X is critical"?
- **Context window bloat**: Each reviewer gets "plan + checklist + context summary" but no size limits defined. Large plans could exceed context windows.

### Missing
- **Fallback strategy**: What if all 9 angles are exhausted before 10 rounds? Plan doesn't specify.
- **Performance benchmarks**: No comparison of review quality vs current 2-round system. How do we measure if this actually improves outcomes?
- **Reviewer workload balancing**: Some angles (Security, Technical Feasibility) require deep analysis while others (Clarity) are lighter. No load balancing consideration.
- **Integration testing**: How does this interact with existing `@review` command and subagent delegation patterns?
- **Rollback plan**: If this system proves too slow/expensive, how do we revert to the old system?

### Critical Gaps
- **Task 2 scope creep**: Adding "Phase 1.5" between existing phases could break current planning workflows. Need explicit backward compatibility verification.
- **Subagent resource limits**: No mention of timeout, memory, or concurrent execution limits for the parallel reviewers.
- **Error handling**: What if a reviewer subagent crashes or returns malformed output?

### Verdict: REQUEST CHANGES

**Blocking issues:**
1. ~~**Undefined angle selection algorithm**~~ → DONE: Added Angle Selection Guide with complexity-based table
2. ~~**Missing conflict resolution mechanism**~~ → DONE: Added Conflict Resolution protocol (goal-aligned evaluation + user escalation)
3. ~~**No resource/performance constraints**~~ → DONE: Added Resource Constraints (parallel cap, timeout, context size, error handling)

**Required additions:**
- ~~Angle selection decision tree based on plan characteristics~~ → DONE
- ~~Conflict resolution protocol for contradictory reviewer feedback~~ → DONE
- ~~Resource limits (timeout, max parallel subagents, context size caps)~~ → DONE
- Backward compatibility verification for Phase 1.5 insertion → ADDRESSED: Phase 1.5 is additive, existing phases unchanged (verified by checklist item)

### Round 1 - Testability

**Mission:** Testability - Are the 13 checklist verify commands adequate? Can failures actually be detected by these commands? Are there acceptance criteria that lack verification?

**Findings:**

**Weak Verifications:**
- Item 4 "Angle pool table present" uses `grep -q "Angle Pool"` - only checks for text existence, not table structure or completeness of 9 angles
- Item 5 "Complexity-based angle count (3-7)" uses `grep -q "3-7"` - could match unrelated text, doesn't verify the selection logic is implemented
- Item 6 "Rotation rule documented" uses `grep -q "different angles"` - too vague, doesn't verify the actual rotation mechanism
- Item 10 "Existing Phase 0/1/2/3 intact" uses phase count but doesn't verify Phase 1.5 insertion didn't break phase flow
- Items 11-13 only check for section headers, not content quality or implementation details

**Missing Verifications:**
- No verification that angle missions and output formats are properly defined in the angle pool table
- No check that conflict resolution protocol includes both goal-aligned evaluation AND user escalation steps
- No verification that resource constraints specify parallel caps, timeouts, and error handling
- No test that the review packet format includes all three components (plan summary, checklist, context)
- No validation that Phase 1.5 properly integrates between existing phases without workflow disruption

**Suggested Improvements:**
- Replace `grep -q "Angle Pool"` with `grep -c "| Angle |" skills/planning/SKILL.md | grep -q "9"` to verify table has 9 angle rows
- Add `grep -q "goal-aligned evaluation.*user escalation" skills/planning/SKILL.md` for conflict resolution completeness
- Add `grep -q "parallel.*timeout.*error handling" skills/planning/SKILL.md` for resource constraints verification
- Replace vague text searches with specific implementation checks (e.g., verify rotation logic, not just "different angles" text)
- Add integration test: verify Phase 1.5 appears between Phase 1 and Phase 2 in correct sequence

**Verdict:** REJECT

**Specific Reasons:**
1. **Surface-level verification**: Most grep commands only check for keyword presence, not implementation correctness
2. **False positive risk**: Vague patterns like "3-7" and "different angles" could match unrelated content
3. **Missing critical checks**: No verification of table completeness, protocol steps, or integration correctness
4. **Inadequate failure detection**: Current commands would pass even if implementations are incomplete or broken

The verification strategy needs to shift from text existence to structural and logical correctness validation.

### Round 2 - Rollback Safety

**Mission:** Rollback Safety

**Findings:**

**Failure Modes:**
- **Performance degradation**: 3-7 parallel subagents × 5 rounds = up to 35 subagent calls per plan vs current 2 calls. Could make planning prohibitively slow (5-10x longer).
- **Cost explosion**: Each subagent call has compute cost. System could become too expensive for frequent use, forcing teams to skip reviews.
- **Reviewer disagreement deadlock**: With 9 different angles, contradictory feedback becomes likely. Goal-aligned resolution may not resolve fundamental conflicts, leading to endless revision cycles.
- **Complexity overwhelm**: Users may find multi-angle feedback too complex to process, preferring simpler 2-round system despite lower quality.
- **Resource exhaustion**: Parallel subagent limits (4 per batch) could cause timeouts or failures under load, making system unreliable.

**Rollback Options:**
- **Clean revert possible**: Changes are purely additive to two markdown skill files. Original Phase 1 review logic remains intact - can simply remove Phase 1.5 section and angle-based subsection.
- **Gradual rollback**: Can disable specific angles by commenting out rows in angle pool table, reducing complexity incrementally.
- **Hybrid fallback**: Can modify complexity assessment to default to 2-round system for most plans, using adversarial review only for high-risk plans.
- **Emergency disable**: Single line change to skip Phase 1.5 entirely: comment out the phase header, system falls back to original 2-round flow.

**Rollback Strategy:**
1. **Monitoring approach**: Track review duration, cost per plan, and user satisfaction metrics
2. **Failure thresholds**: If average review time >10 minutes or cost >$5 per plan, initiate rollback discussion
3. **Quick disable**: Comment out `## Phase 1.5: Adversarial Review` header to immediately revert to 2-round system
4. **Full revert**: Remove added sections from both skill files, restoring original review behavior
5. **No data loss**: All existing plans and workflows remain functional during rollback

**Verdict:** APPROVE

**Specific reasons:**
1. **Clean rollback path**: Changes are additive to markdown files with clear section boundaries - easy to remove
2. **No breaking changes**: Original 2-round review logic preserved, system can fall back gracefully
3. **Incremental disable**: Can reduce complexity gradually (disable angles, reduce rounds) rather than all-or-nothing
4. **No infrastructure dependencies**: Pure prompt-driven system means no databases, APIs, or external services to migrate during rollback
5. **Immediate emergency disable**: Single comment can disable entire system in under 30 seconds if critical issues arise

The rollback safety is excellent due to the additive, markdown-based implementation approach.

### Round 2 Review

**Changes assessed:** Added Angle Selection Guide table, Conflict Resolution protocol, Resource Constraints section, and 3 new checklist items (total now 13).

### Strengths
- **All blocking fixes addressed**: The three critical issues from Round 1 have concrete solutions
- **Practical angle selection**: Complexity-based table provides clear guidance for 3-7 angle selection
- **Pragmatic conflict resolution**: Goal-aligned evaluation with user escalation fallback handles contradictory feedback
- **Resource awareness**: Parallel caps, timeouts, context limits, and crashed subagent handling are specified
- **Comprehensive checklist**: 13 verification items cover all major components

### Weaknesses
- **Angle Selection Guide rigidity**: Table categories may not fit mixed-characteristic plans cleanly
- **Conflict resolution complexity**: "Goal-aligned evaluation" requires sophisticated main agent judgment
- **Resource constraint vagueness**: "Normal limits" and "typically 4" lack precision

### Missing
- **Performance metrics**: No measurement approach for review quality improvement vs 2-round system
- **Rollback strategy**: No reversion plan if system proves too expensive/slow
- **Integration testing**: No verification approach for existing `@review` workflow compatibility

### Verdict: **APPROVE**

The three Round 1 blocking issues are adequately resolved:
1. ✅ Angle selection algorithm via complexity-based guide
2. ✅ Conflict resolution via goal-aligned evaluation + escalation  
3. ✅ Resource constraints via parallel caps + error handling

Remaining weaknesses are refinements that don't block implementation. Plan is executable with clear decision guidance.

### Round 1 - Over-engineering

**Mission:** Over-engineering (YAGNI)

**Findings:**
- **9-angle pool excessive**: Security, Performance, Rollback Safety angles rarely needed for typical plans. Most plans are simple file modifications that don't warrant security analysis or performance optimization. Pool could be reduced to 5 core angles: Technical Feasibility, Completeness, Testability, Compatibility, Clarity.
- **10-round cap too high**: Current 2-round system works for 90% of plans. Even adversarial review shouldn't need more than 5 rounds for complex plans. 10 rounds = potential 70 subagent calls, which is resource waste.
- **Parallel execution overkill**: 3-7 simultaneous subagents per round adds complexity without proven benefit. Sequential review with 2-3 angles would achieve similar quality with simpler orchestration.
- **Angle Selection Guide over-specified**: Complex decision matrix for angle selection when simple heuristic would suffice: "3 angles for simple plans, 4-5 for complex plans."
- **Conflict Resolution mechanism unnecessary**: If angles are well-chosen, conflicts should be rare. Adding resolution protocol assumes frequent conflicts that may not occur.
- **Research Dimension Principle scope creep**: Adding theoretical+practice requirement to Phase 0 is unrelated to review improvement and expands scope unnecessarily.

**Verdict:** REJECT

**Specific reasons:**
1. **Complexity explosion**: System jumps from 2 reviewer calls to potentially 70 calls (10 rounds × 7 angles) without evidence this improves outcomes
2. **Premature optimization**: Addresses theoretical "rubber stamp" problem without measuring current review effectiveness
3. **Feature creep**: Research dimension principle and elaborate conflict resolution add complexity beyond core goal
4. **Resource waste**: Most plans don't need security/performance/rollback analysis but system assumes they do

**Simplification suggestions:**
- Reduce to 4 core angles: Feasibility, Completeness, Testability, Clarity
- Cap at 3 rounds maximum
- Use sequential review (1 angle per round) instead of parallel
- Remove conflict resolution mechanism
- Remove research dimension addition
- Simple angle selection: "Use all 4 angles for every plan"

### Round 2 - Performance

**Mission:** Performance - Check for resource waste, context window bloat, unnecessary subagent calls. Is the cost proportional to the benefit?

**Findings:**
- **Massive resource scaling**: Plan increases from 2 subagent calls to potentially 35 calls (7 angles × 5 rounds). Context shows current system uses 1-2 calls total. This is a 17x-35x increase in computational cost.
- **Context window inefficiency**: Each reviewer receives "plan header + checklist + 3-sentence context" but no size limits. Large plans could generate massive review packets sent to multiple parallel subagents, multiplying context consumption.
- **Batching overhead**: With 4-subagent parallel limit and up to 7 angles, requires 2 batches per round (4+3), adding orchestration complexity and latency. Sequential execution would be simpler and nearly as fast.
- **Angle pool bloat**: 9 angles defined but most plans only need 3-4. System will consistently over-provision reviewers for simple changes.
- **Redundant verification**: 13 checklist items mostly use simple grep commands that could be consolidated into fewer, more comprehensive checks.
- **Unnecessary parallel complexity**: Parallel reviewer dispatch adds significant orchestration overhead (batching, error handling, result aggregation) without proven speed benefit over sequential review.

**Verdict:** REJECT

**Specific reasons:**
1. **Disproportionate cost increase**: 17x-35x more subagent calls than current system without demonstrated quality improvement
2. **Context waste**: No size controls on review packets could lead to massive token consumption across multiple parallel subagents  
3. **Over-engineering**: Complex parallel orchestration when sequential review would achieve similar results with simpler implementation
4. **Resource planning failure**: No cost-benefit analysis or performance benchmarks to justify the massive resource increase

## Tasks

### Task 1: Update reviewing skill with angle-based review protocol

**Files:**
- Modify: `skills/reviewing/SKILL.md`

**Changes:**
- Add "### Angle-Based Plan Review" subsection under Plan Review Mode
- Define: each reviewer receives an assigned angle with mission + output format
- Define: structured output template (Mission / Findings / Verdict)
- Define: reviewer must deeply challenge from their angle, not rubber-stamp

### Task 2: Add multi-angle orchestration to planning skill

**Files:**
- Modify: `skills/planning/SKILL.md`

**Changes:**
- Replace the implicit "dispatch reviewer" pattern in Phase 1 with a new "## Phase 1.5: Adversarial Review" section between Phase 1 (Writing) and Phase 2 (Execution)
- Define: complexity assessment → angle selection (3-7) → parallel dispatch in batches of 4 → collect → fix → rotate → repeat
- Define: termination conditions (all APPROVE in one round, or 5-round cap)
- Define: angle pool table with missions and outputs
- Define: review packet format (plan summary, checklist, context)

### Task 3: Add research dimension principle to Phase 0

**Files:**
- Modify: `skills/planning/SKILL.md`

**Changes:**
- In Phase 0 Step 3 (Research), add principle: research must cover theoretical + engineering practice dimensions

## Checklist

- [x] Angle-based review subsection exists in reviewing skill | `grep -q "### Angle-Based Plan Review" skills/reviewing/SKILL.md`
- [x] Structured output template defined | `grep -q "Mission / Findings / Verdict" skills/reviewing/SKILL.md`
- [x] Phase 1.5 section exists in planning skill | `grep -q "## Phase 1.5: Adversarial Review" skills/planning/SKILL.md`
- [x] Phase 1.5 appears between Phase 1 and Phase 2 | `awk '/## Phase 1\.5/{p15=NR} /## Phase 2/{p2=NR} END{exit (p15 < p2 ? 0 : 1)}' skills/planning/SKILL.md`
- [x] Angle pool table has all angles with missions | `grep -c "| .* | .* | .* |" skills/planning/SKILL.md | awk '{exit ($1 >= 9 ? 0 : 1)}'`
- [x] Complexity-based angle selection guide present | `grep -q "Angle Selection Guide" skills/planning/SKILL.md`
- [x] Rotation rule: different from previous round | `grep -q "different angles than the immediately previous round" skills/planning/SKILL.md`
- [x] 5-round hard cap documented | `grep -q "5 rounds" skills/planning/SKILL.md`
- [x] Review packet format defined with 3 components | `grep -q "Goal.*Architecture.*Checklist.*context summary" skills/planning/SKILL.md`
- [x] Conflict resolution references Goal statement | `grep -q "Goal.*statement" skills/planning/SKILL.md`
- [x] Resource constraints specify batch limit of 4 | `grep -q "4 (tool hard limit)" skills/planning/SKILL.md`
- [x] Error handling for crashed reviewers defined | `grep -q "fewer than half" skills/planning/SKILL.md`
- [x] Research dimension principle added to Phase 0 | `grep -q "engineering practice" skills/planning/SKILL.md`
- [x] Existing Phase 0/1/2/3 intact | `grep -c "## Phase [0123]:" skills/planning/SKILL.md | grep -q "4"`
- [x] Reviewer calibration (90/100 bar) documented | `grep -q "90/100" skills/planning/SKILL.md`

### Round 2 - Compatibility

**Mission:** Compatibility

**Findings:**
- **Existing @review workflow preserved**: Current AGENTS.md routes `@review` command to reviewing skill, and plan only adds new "Angle-Based Plan Review" subsection without modifying existing Plan Review Mode or Code Review Mode. The 4-step devil's advocate approach and structured output format remain intact.
- **Phase structure maintained**: Plan adds Phase 1.5 between existing Phase 1 (Writing) and Phase 2 (Execution), but all existing phases (0: Deep Understanding, 1: Writing, 2: Execution, 3: Completion) remain unchanged. This is additive insertion, not modification.
- **Subagent delegation patterns compatible**: Current framework uses "reviewer subagent" for plan review (confirmed in AGENTS.md). Plan enhances this by dispatching multiple reviewer subagents in parallel batches, but maintains the same delegation principle. Resource constraints section addresses the 4-subagent parallel limit.
- **Reviewing skill output format preserved**: Current Plan Review Mode outputs "Strengths / Weaknesses / Missing / Verdict" while new angle-based review uses "Mission / Findings / Verdict". Both maintain the critical APPROVE/REJECT verdict structure that downstream processes depend on.
- **No breaking changes to execution strategies**: Phase 2 execution strategies (Sequential/Parallel/Subagent per task) are unaffected since Phase 1.5 occurs before Phase 2 and only modifies the review process, not execution.
- **Backward compatibility risk**: Plans written before this change will lack the new angle pool table and complexity assessment, but existing plans can still be reviewed using current Plan Review Mode since both modes coexist.

**Verdict:** APPROVE

**Specific reasons:**
1. **Additive design**: Phase 1.5 insertion preserves all existing phase functionality
2. **Dual-mode compatibility**: New angle-based review coexists with existing Plan Review Mode
3. **Subagent pattern consistency**: Enhances existing reviewer subagent delegation without changing the fundamental pattern
4. **Output format compatibility**: Both old and new review modes maintain APPROVE/REJECT verdict structure
5. **No workflow disruption**: @review command routing and skill execution remain unchanged

### Round 2 - Security

**Mission:** Security

**Findings:**
- **No authentication risks**: Plan modifies only markdown skill files, no auth mechanisms involved
- **No data exposure concerns**: Review system processes plan content that's already in local files, no external data transmission
- **No injection surfaces**: Reviewers write structured text to markdown files using predefined templates, no code execution or dynamic content generation
- **No secrets handling**: System deals with plan metadata and review feedback, no credentials or sensitive data processing
- **Subagent isolation confirmed**: Each reviewer receives only review packet (plan header + checklist + context), not full system access
- **File write scope limited**: Reviewers append to specific plan sections only, cannot modify arbitrary files
- **No network operations**: Entire review process operates on local markdown files, no external API calls or data transmission
- **Input validation implicit**: Structured output format (Mission/Findings/Verdict) provides natural bounds on reviewer output

**Verdict:** APPROVE

**Specific reasons:**
1. **Minimal attack surface**: Markdown-only modifications with no code execution or external dependencies
2. **Contained scope**: Reviewers operate within predefined file sections and output templates
3. **No sensitive data**: Plan content and review feedback contain no credentials or private information
4. **Local operation**: No network exposure or external system integration risks

### Round 3 - Technical Feasibility

**Mission:** Technical Feasibility

**Findings:**
- **Parallel batching resolved**: Context confirms batching in groups of 4 explicitly designed since Round 1. Plan specifies "dispatch in batches of 4 then remainder" which addresses the tool limit constraint.
- **Context window risk mitigated**: Review packet concretized as "plan header + checklist + 3-sentence summary" which is small and bounded, addressing previous context window concerns.
- **Error handling defined**: Half-complete restart rule and malformed output handling (missing structure) are specified in Resource Constraints section, resolving previous gaps.
- **5-round cap reduces worst case**: Maximum 35 calls (7 angles × 5 rounds) vs previous 70 calls (7 × 10 rounds), making resource usage more reasonable.
- **File write conflicts avoided**: Reviewers append to specific plan sections under "## Review" with round-specific headers, preventing concurrent write issues.
- **Subagent capabilities confirmed**: Reviewing skill shows reviewer subagents can read files and write structured output, supporting the required functionality.
- **Integration path clear**: Plan adds "### Angle-Based Plan Review" subsection to existing reviewing skill without breaking current Plan Review Mode, maintaining backward compatibility.

**Verdict:** APPROVE

**Specific reasons:**
1. **Batching constraint addressed**: Groups of 4 design handles parallel limit properly
2. **Bounded context**: Small review packets prevent context window issues  
3. **Error recovery defined**: Clear rules for crashed/malformed reviewer handling
4. **Resource scaling reasonable**: 35-call worst case is manageable vs previous 70-call concern
5. **No file conflicts**: Sequential round-based appending prevents write collisions
6. **Tool compatibility**: Current reviewer subagent capabilities support required operations

### Round 3 - Testability

**Mission:** Testability - Are the checklist verify commands adequate? Can failures be detected?

**Findings:**
- **Item 5 angle count verification weak**: `grep -c "| .* | .* | .* |" | awk '{exit ($1 >= 9 ? 0 : 1)}'` counts any 4-column table rows, not specifically angle pool entries. Could pass with unrelated tables.
- **Item 7 rotation rule too vague**: `grep -q "different angles than the immediately previous round"` only checks for text presence, not implementation of actual rotation logic.
- **Item 9 review packet verification incomplete**: `grep -q "Goal.*Architecture.*Checklist.*context summary"` uses loose pattern that could match scattered text, doesn't verify proper packet structure.
- **Item 11 resource constraints check imprecise**: `grep -q "4 (tool hard limit)"` searches for exact phrase but doesn't verify the batching logic or parallel dispatch implementation.
- **Item 12 error handling verification surface-level**: `grep -q "fewer than half"` only confirms text exists, doesn't validate the restart-round logic or malformed output handling.
- **Phase ordering check robust**: Item 4 using awk to verify Phase 1.5 appears between Phase 1 and Phase 2 is solid - would catch ordering failures.
- **Table row count verification improved**: Item 5 counting table rows with awk is more precise than simple text search.
- **Missing verification for angle missions**: No check that each angle in the pool table has both mission and output format defined.
- **No validation of conflict resolution completeness**: Should verify both goal-aligned evaluation AND user escalation are documented.

**Verdict:** APPROVE

**Specific reasons:**
1. **Significant improvement from Round 1**: Commands upgraded from simple grep to awk-based structural validation and row counting
2. **Phase ordering verification robust**: Awk command properly validates Phase 1.5 insertion between existing phases
3. **Table structure validation adequate**: Row counting approach can detect missing angles even if not perfect
4. **90/100 threshold met**: While some commands could be more precise, they would catch major implementation failures like missing sections, wrong phase order, or incomplete tables
5. **Failure detection sufficient**: Commands would fail on broken implementations - missing angle pool, wrong phase sequence, absent resource constraints

### Round 3 - Completeness

**Mission:** Completeness

**Findings:**
- **Missing batch execution details**: Plan states "dispatch in batches of 4" but doesn't specify whether batches run sequentially or if there's delay between batches. Could cause timing issues.
- **Undefined "half-complete" threshold**: Error handling says "if fewer than half of the round's reviewers complete, restart the round" but doesn't define what constitutes "complete" vs "incomplete" (crashed vs malformed output vs timeout).
- **Context isolation gaps**: Plan specifies reviewers don't see each other's feedback within a round, but doesn't address whether reviewers in later rounds see previous round feedback, which could bias rotation effectiveness.
- **Review packet size limits missing**: "3-sentence context summary" is defined but no limits on plan header or checklist size, which could exceed reviewer context windows for large plans.
- **Angle reuse tracking undefined**: Rotation rule allows reuse "after skipping one round" but doesn't specify how the system tracks which angles were used in which rounds across the 5-round cap.

**Verdict:** APPROVE

**Specific reasons:**
1. **Core execution path complete**: Plan can be executed end-to-end with complexity assessment → angle selection → parallel dispatch → collect results → fix → repeat logic
2. **Error boundaries defined**: 5-round cap and half-complete restart rule prevent infinite loops and handle major failures
3. **Integration points specified**: Clear modification targets (2 skill files) with specific sections and verification commands
4. **Minor gaps don't block execution**: Missing details like batch timing and context isolation are implementation refinements that won't cause plan failure

### Round 3 - Clarity

**Mission:** Clarity

**Findings:**
- **"Review packet = plan header + checklist + 3-sentence context"** - Clear definition provided in Resource Constraints section
- **"Different from immediately previous round"** - Rotation rule is now unambiguous with explicit clarification that angles can be reused after skipping one round
- **"5 rounds max"** - Hard cap clearly stated with exact termination message specified
- **"Batches of 4"** - Parallel execution limits clearly defined with tool constraint explanation
- **"Fewer than half complete"** - Error handling threshold is specific and measurable
- **Angle Selection Guide** - Provides concrete criteria linking plan characteristics to angle counts
- **Conflict Resolution** - Step-by-step process defined with goal-alignment evaluation and user escalation fallback
- **All technical terms defined** - Resource constraints, review packet format, and error handling procedures are concrete

**Verdict:** APPROVE

**Specific reasons:**
1. **All ambiguities from Round 1 resolved** - Rotation rule, review packet format, error handling, and termination conditions are now concrete
2. **Executable instructions** - Agent can follow the complexity assessment → angle selection → parallel dispatch workflow without interpretation
3. **Measurable criteria** - "Fewer than half", "5 rounds max", "batches of 4" provide clear decision points
4. **Complete definitions** - No undefined terms or abstract concepts remain that would cause implementation confusion
