# Review Flow Optimization — Progress Log

## Iteration 1 — Task 1: Reduce Round Cap and Add Round 2+ Reviewer Rule

**Status:** Complete

**Changes made to `skills/planning/SKILL.md`:**
1. Changed "or 5 rounds reached" → "or 3 rounds reached" (line 256)
2. Changed "After 5 rounds: stop..." → "After 3 rounds: stop..." (line 257)
3. Added Round 2+ reviewer count rule before item 7 (line 255): "Dispatch only 2 reviewers (the 2 fixed angles: Goal Alignment + Verify Correctness). Do NOT sample random angles in Round 2+."
4. Updated Resource Constraints: "Fixed at 4 per round" → "Round 1: 4 reviewers. Round 2+: 2 reviewers (fixed angles only)."

**Verification output:**
- `grep -n "or 3 rounds reached"` → line 256 ✓
- `grep -n "After 3 rounds"` → line 257 ✓
- `grep -n "Round 2+ reviewer count"` → line 255 ✓
- `grep -A5 "Resource Constraints" | grep "Round 2+: 2 reviewers"` → match ✓
- `grep "5 rounds"` → no matches ✓

**Note:** Plan verify command for checklist item 4 had awk bug (`/^##/` matched `### Resource Constraints` itself, collapsing range to 1 line). Fixed verify command in plan to use `grep -A5` instead. Implementation is correct.

## Iteration 2 — Tasks 2+3: Add Fill-in Templates to Completeness and Testability Angles

**Status:** Complete

**Changes made to `skills/planning/SKILL.md`:**
1. Replaced Completeness Mission cell with fill-in template: "You MUST copy each table below and fill EVERY cell..." with two structured tables (functions/branches + error paths) and SCOPE constraint.
2. Replaced Testability Mission cell with fill-in template: "You MUST copy this table and fill EVERY cell..." with false-negative analysis table.

**Files changed:** `skills/planning/SKILL.md`

**Verification output:**
- `awk '/\| Completeness/,/\|/' | grep -q 'You MUST copy each table below...'` → PASS ✓
- `awk '/\| Testability/,/\|/' | grep -q 'You MUST copy this table...'` → PASS ✓
- Random pool angle count: 7 angles confirmed (8 rows matched `^| [A-Z]` but 1 is the header `| Angle |`) → PASS ✓

**Learnings:**
- Verify command `grep -c '^| [A-Z]'` counted 8 not 7 because the table header row `| Angle |` starts with `| A` and matches the pattern. Fixed verify to pipe through `grep -cv '^| Angle '` to exclude the header. Rule: when counting table body rows, always exclude the header row explicitly.
- The awk range `/\| Completeness/,/\|/` works correctly here because Completeness is a long single-line table cell — awk stops at the next line starting with `|` which is the Testability row.
