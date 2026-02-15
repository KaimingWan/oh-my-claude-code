# Reviewing Skill Enhancement Plan

**Goal:** Enhance reviewing skill to be a focused code review skill with full checklist depth from archived v2 skills, clear triggering rules, and structured output.
**Architecture:** SKILL.md as flow navigator (7-step code review + receiving review), references/ directory for deep checklists. Plan review removed (owned by planning skill).
**Tech Stack:** Markdown skill files

## Review

### Round 1 (single reviewer, old protocol — ~~deprecated~~)
Used old Strengths/Weaknesses/Missing format instead of Phase 1.5 adversarial review. Result: APPROVE after 2 rounds. Superseded by Round 2.

### Round 2 (Phase 1.5 adversarial review, 4 angles)

**Angles selected:** Completeness, Compatibility, Testability, Clarity (Multi-file internal refactor)

| Angle | Verdict | Key Finding |
|-------|---------|-------------|
| Completeness | APPROVE | output-format.md source not explicit — non-blocking |
| Compatibility | APPROVE | Breaking changes are intentional architecture improvements |
| Testability | APPROVE | All verify commands correctly detect failures |
| Clarity | REJECT | Task 0 path misaligned with Task 1, duplicate Step 4 unspecified |

**Fixes applied:**
- Task 0: explicit path alignment with Task 1 source
- Task 1: output-format.md source specified (reference-skill.md sections 6+7)
- Task 3: AGENTS.md pre-verify step, commands/plan.md renumbering specified

**Quality Assessment:**
- Plan is complete and executable
- Acceptance criteria are verifiable with shell commands
- Architecture decisions are sound
- Risk mitigation is adequate

### Strengths
- Clear architectural separation: SKILL.md as navigator, references/ for deep checklists
- Concrete checklist with verifiable acceptance criteria using shell commands
- Removes plan review overlap with planning skill (good separation of concerns)
- 7-step structured code review flow provides systematic coverage
- Enhanced receiving review with YAGNI check and implementation order prioritization
- References archived v2 skills that had proven checklist depth

## Checklist

- [x] SKILL.md contains no plan review content | `! grep -qi "plan review" skills/reviewing/SKILL.md`
- [x] SKILL.md references all 5 reference files | `for f in solid-checklist security-checklist code-quality-checklist removal-plan output-format; do grep -q "$f" skills/reviewing/SKILL.md || exit 1; done`
- [x] All 5 reference files exist | `ls skills/reviewing/references/solid-checklist.md skills/reviewing/references/security-checklist.md skills/reviewing/references/code-quality-checklist.md skills/reviewing/references/removal-plan.md skills/reviewing/references/output-format.md`
- [ ] Old reference.md removed | `! test -f skills/reviewing/reference.md`
- [ ] SKILL.md has 7-step code review flow | `grep -c "^### [0-9])" skills/reviewing/SKILL.md | grep -q "[7-9]"`
- [ ] Receiving Review has YAGNI check | `grep -qi "yagni" skills/reviewing/SKILL.md`
- [ ] Receiving Review has implementation order | `grep -qi "implementation order\|blocking.*simple.*complex" skills/reviewing/SKILL.md`
- [ ] AGENTS.md review entry updated | `grep -i "code review" AGENTS.md`
- [ ] commands/plan.md Step 4 references Phase 1.5 | `grep -q "Phase 1.5\|adversarial review\|planning skill" commands/plan.md`
- [ ] commands/plan.md no longer has hardcoded review format | `! grep -q "Strengths.*Weaknesses.*Missing.*Verdict" commands/plan.md`
- [ ] planning skill Phase 1.5 title says "Plan Review" | `grep -q "## Phase 1.5: Plan Review" skills/planning/SKILL.md`

---

### Task 0: Validate source files

**Verify:** All 4 archived reference files exist at the exact path used by Task 1:
```bash
for f in solid-checklist security-checklist code-quality-checklist removal-plan; do
  test -s "archive/v2/claude-skills/code-review-expert/references/${f}.md" || { echo "MISSING: $f"; exit 1; }
done
```

### Task 1: Create reference files

**Files:**
- Create: `skills/reviewing/references/solid-checklist.md`
- Create: `skills/reviewing/references/security-checklist.md`
- Create: `skills/reviewing/references/code-quality-checklist.md`
- Create: `skills/reviewing/references/removal-plan.md`
- Create: `skills/reviewing/references/output-format.md`

Copy from `archive/v2/claude-skills/code-review-expert/references/` for the first 4 files. Create `output-format.md` by combining content from `archive/v2/claude-skills/code-review-expert/reference-skill.md` sections 6 (output format) and 7 (next steps), plus adding a clean review declaration section.

### Task 2: Rewrite SKILL.md

**Files:**
- Modify: `skills/reviewing/SKILL.md`

Rewrite with:
1. Updated frontmatter (description = code review focused)
2. Requesting Review (keep existing, minor cleanup)
3. Executing Code Review — 7-step structured flow:
   - 1) Preflight context (git diff scope, >500 line batching)
   - 2) SOLID + architecture → ref solid-checklist.md
   - 3) Security scan → ref security-checklist.md
   - 4) Code quality scan → ref code-quality-checklist.md
   - 5) Removal candidates → ref removal-plan.md
   - 6) Output → ref output-format.md
   - 7) Next steps confirmation
4. Receiving Review — enhanced:
   - Core 6-step flow (keep)
   - YAGNI check
   - Implementation order (blocking → simple → complex)
   - Simplified push back guidance
   - Acknowledging correct feedback format

Remove: Plan Review Mode, Angle-Based Plan Review.

### Task 3: Cleanup, AGENTS.md, and commands/plan.md update

**Files:**
- Delete: `skills/reviewing/reference.md`
- Modify: `AGENTS.md`
- Modify: `commands/plan.md`

1. Update AGENTS.md skill routing table: change `| Review | reviewing | \`@review\` 命令 |` to `| Code Review | reviewing | \`@review\` 命令 |`. Verify target line first: `grep -n "| Review | reviewing" AGENTS.md`

2. Update `commands/plan.md`:
   - Current Step 4 "Reviewer Challenge" (lines 12-15): replace with instruction to follow `skills/planning/SKILL.md` Phase 1.5 plan review (angle selection based on plan complexity, multi-reviewer dispatch, calibration rules). Do NOT hardcode review format.
   - Current second "Step 4" → rename to "Step 5: Address Feedback"
   - Current "Step 5" → "Step 6: User Confirmation"
   - Current "Step 6" → "Step 7: Hand Off to Execute"

3. Rename `skills/planning/SKILL.md` Phase 1.5 title: "Adversarial Review" → "Plan Review". Update all references to "adversarial review" in that file to "plan review".
