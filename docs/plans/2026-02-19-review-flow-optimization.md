# Review Flow Optimization

**Goal:** Improve plan review quality and efficiency by reducing max rounds from 5 to 3, using 2 reviewers (not 4) for Round 2+, and adding fill-in templates to Completeness and Testability angles.
**Non-Goals:** Restructuring the review flow (e.g., splitting into discovery/verdict phases), changing the random angle pool size, changing reviewer prompt calibration, modifying execution-phase Socratic checks.
**Architecture:** Three targeted edits to `skills/planning/SKILL.md` Phase 1.5 section — change round cap, add Round 2+ reviewer reduction rule, convert Completeness/Testability missions to fill-in templates.
**Tech Stack:** Markdown only (no code changes)

## Review

Round 1 (4 reviewers parallel):
- Goal Alignment: APPROVE — all 3 tasks map to goal phrases, execution order valid (no dependencies between tasks)
- Verify Correctness: REQUEST CHANGES — 3 findings: Item 5 false positive (phrase already exists in Goal Alignment), Item 7 false positive (regression check always passes), Item 8 count ambiguity. **Fixed:** all 8 verify commands rewritten — added `! grep` negative checks, `awk` section-scoping, fixed count logic
- Completeness: APPROVE — all modified sections covered by tasks
- Testability: REQUEST CHANGES — location-agnostic grep could pass with text in wrong location. **Fixed:** verify commands now use `awk` to scope to correct section before grep. Partial-edit concern dismissed: checklist items 1+2 are separate checks for the two "5→3" lines

Round 2 (2 fixed-angle reviewers — verifying fixes):
- Goal Alignment: APPROVE — all tasks map to goal, no dependencies, execution order valid
- Verify Correctness: APPROVE — all 8 verify commands sound, section-scoped awk fixes confirmed working

## Tasks

### Task 1: Reduce Round Cap and Add Round 2+ Reviewer Rule

**Files:**
- Modify: `skills/planning/SKILL.md`

**What to change:**

In the `### Orchestration` section:

1. Line "Repeat until all APPROVE in a single round, or 5 rounds reached" → change `5` to `3`
2. Line "After 5 rounds: stop and tell user..." → change `5` to `3`
3. Add new rule after item 6 (Round 2+ rule):

```
   **Round 2+ reviewer count:** Dispatch only 2 reviewers (the 2 fixed angles: Goal Alignment + Verify Correctness). Do NOT sample random angles in Round 2+. Purpose of Round 2+ is to verify fixes, not discover new issues.
```

4. In `### Resource Constraints`, update: "Fixed at 4 per round" → "Round 1: 4 reviewers. Round 2+: 2 reviewers (fixed angles only)."

**Verify:** Confirm the 4 changes are present:
- `or 3 rounds reached` exists
- `After 3 rounds` exists
- `Round 2+ reviewer count` section exists
- `Round 2+: 2 reviewers` exists in Resource Constraints

### Task 2: Add Fill-in Template to Completeness Angle

**Files:**
- Modify: `skills/planning/SKILL.md`

**What to change:**

Replace the Completeness row's Mission cell in the random pool table with:

```
You MUST copy each table below and fill EVERY cell. Missing rows = review REJECTED.\n\nFor each file in the plan's Files: fields that is MODIFIED (not created), copy and fill:\n\n\| File \| Function/Branch \| Exercised by Task # \| Coverage? \|\n\|------\|----------------\|--------------------\|-----------\|\n\| [path] \| [name] \| [task # or NONE] \| [Y/N] \|\n\nThen for each error path (try/except, if-error-return, signal handler) in modified files:\n\n\| File:line \| Error path \| Exercised by Task # \|\n\|----------\|------------|--------------------\|\n\| [path:line] \| [description] \| [task # or NONE] \|\n\nSCOPE: Only analyze functions/branches in files the plan MODIFIES. Do NOT flag functions in files the plan merely reads.
```

Keep the Analysis Method as "Source-to-task traceability matrix" and Output as "Uncovered Functions / Unexercised Error Paths / Verdict".

**Verify:** Confirm the Completeness row contains `You MUST copy each table below and fill EVERY cell`

### Task 3: Add Fill-in Template to Testability Angle

**Files:**
- Modify: `skills/planning/SKILL.md`

**What to change:**

Replace the Testability row's Mission cell in the random pool table with:

```
You MUST copy this table and fill EVERY cell. Missing rows = review REJECTED.\n\nFor each Task's test case:\n\n\| Task # \| Assertion (what property) \| Minimal wrong impl that passes \| False negative? \|\n\|--------\|--------------------------|-------------------------------|----------------\|\n\| [N] \| [what is checked] \| [describe wrong impl] \| [Y/N + reason] \|\n\nOnly flag tests where you can construct a concrete wrong implementation that passes. "Might be weak" without a specific wrong impl = not actionable.
```

Keep the Analysis Method as "False negative analysis per test" and Output as "Weak Assertions / False Negative Risks / Verdict".

**Verify:** Confirm the Testability row contains `You MUST copy this table and fill EVERY cell`

## Checklist

- [x] Round cap changed from 5 to 3 | `grep -q 'or 3 rounds reached' skills/planning/SKILL.md && ! grep -q 'or 5 rounds reached' skills/planning/SKILL.md`
- [x] "After 3 rounds" message updated | `grep -q 'After 3 rounds' skills/planning/SKILL.md && ! grep -q 'After 5 rounds' skills/planning/SKILL.md`
- [x] Round 2+ reviewer reduction rule added | `grep -q 'Round 2+ reviewer count' skills/planning/SKILL.md`
- [x] Resource Constraints updated for Round 2+ | `grep -A5 'Resource Constraints' skills/planning/SKILL.md | grep -q 'Round 2+: 2 reviewers'`
- [ ] Completeness angle has fill-in template | `awk '/\| Completeness/,/\|/' skills/planning/SKILL.md | grep -q 'You MUST copy each table below and fill EVERY cell'`
- [ ] Testability angle has fill-in template | `awk '/\| Testability/,/\|/' skills/planning/SKILL.md | grep -q 'You MUST copy this table and fill EVERY cell'`
- [x] Old "5 rounds" references fully removed | `! grep -q '5 rounds' skills/planning/SKILL.md`
- [ ] Random pool still has 7 angles | `test "$(awk '/Random pool/,/^### Angle Selection/' skills/planning/SKILL.md | grep -c '^| [A-Z]')" -eq 7`

## Errors

| Error | Task | Attempt | Resolution |
|-------|------|---------|------------|
| `awk '/Resource Constraints/,/^##/'` range collapses to 1 line because `### Resource Constraints` matches `^##` pattern | 1 | 1 | Fixed verify command to use `grep -A5 'Resource Constraints'` instead; content is correct |
