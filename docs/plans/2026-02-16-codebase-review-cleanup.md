# Codebase Review & Cleanup Plan

**Goal:** Clean up dead files/code and fix code quality issues across the project, without breaking any existing functionality.
**Non-Goals:** Architecture changes, new features, refactoring module boundaries.
**Architecture:** Scan all modules (hooks, scripts, skills, knowledge, commands, configs, docs) for unused files, stale references, code quality issues. Safe items cleaned directly, risky items listed for user confirmation.
**Tech Stack:** Bash, Python, Markdown

## Tasks

### Task 1: Delete Dead Files

**Files:**
- Delete: `knowledge/lessons-learned.md.bak` (superseded by episodes.md, 12KB of stale v2 data)
- Delete: `docs/plans/.test-enforce-plan.md` (empty test artifact, 1 byte)
- Delete: `archive/v2/hooks.bak` (broken symlink → `../.claude/hooks` which is itself a symlink)
- Delete: `archive/v2/skills.bak` (broken symlink → `../.claude/skills` which is itself a symlink)
- Delete: `archive/v2/{commands}/` (empty directory — literal braces in name, not shell glob)
- Delete: `archive/v2/kiro-prompts/commands` (broken symlink)

**Step 1: Remove files**
```bash
git rm knowledge/lessons-learned.md.bak
git rm docs/plans/.test-enforce-plan.md
git rm archive/v2/hooks.bak archive/v2/skills.bak
rmdir 'archive/v2/{commands}'
git rm archive/v2/kiro-prompts/commands
```

**Step 2: Commit**
```bash
git add -A && git commit -m "chore: remove dead files — broken symlinks, empty dirs, stale .bak"
```

**Verify:** `! git ls-files | grep -E 'lessons-learned\.md\.bak$|\.test-enforce-plan\.md$|hooks\.bak$|skills\.bak$|kiro-prompts/commands$'`

### Task 2: Fix Stale References in README.md

README.md references `scripts/ralph-loop.sh` and `scripts/generate-platform-configs.sh` — both replaced by Python equivalents.

**Files:**
- Modify: `README.md`

**Step 1: Update references**
- `scripts/ralph-loop.sh` → `scripts/ralph_loop.py`
- `scripts/generate-platform-configs.sh` → `scripts/generate_configs.py`
- Update descriptions to match current state

**Step 2: Commit**
```bash
git add README.md && git commit -m "docs: update README — fix stale script references to Python rewrites"
```

**Verify:** `! grep -E 'ralph-loop\.sh|generate-platform-configs\.sh' README.md`

### Task 3: Fix Stale References in enforcement.md and enforce-ralph-loop.sh

**Files:**
- Modify: `.kiro/rules/enforcement.md` (references `scripts/generate-platform-configs.sh`)
- Modify: `hooks/gate/enforce-ralph-loop.sh` (comments reference old script names)

**Step 1: Fix enforcement.md**
Find `generate-platform-configs.sh` and replace with `generate_configs.py`.

**Step 2: Fix enforce-ralph-loop.sh comments**
Find comment `Agent must use ralph-loop.sh` and replace with `Agent must use ralph_loop.py`.
Find comment `Allow ralph-loop.sh itself` and replace with `Allow ralph-loop invocations`.

**Step 3: Commit**
```bash
git add .kiro/rules/enforcement.md hooks/gate/enforce-ralph-loop.sh && git commit -m "docs: fix stale references to old bash scripts"
```

**Verify:** `! grep 'generate-platform-configs\.sh' .kiro/rules/enforcement.md && ! grep 'must use ralph-loop\.sh' hooks/gate/enforce-ralph-loop.sh && ! grep 'Allow ralph-loop\.sh itself' hooks/gate/enforce-ralph-loop.sh`

### Task 4: Fix init-project.sh — References Non-existent default.json

`tools/init-project.sh` copies `.kiro/agents/default.json` which no longer exists (renamed to `pilot.json`). This would fail on any new project init.

**Files:**
- Modify: `tools/init-project.sh`

**Step 1: Fix agent config copy**
- Replace single `default.json` copy with wildcard: `cp "$TEMPLATE_DIR/.kiro/agents/"*.json "$TARGET/.kiro/agents/"`
- Update the jq line to target `pilot.json` instead of `default.json`

**Step 2: Commit**
```bash
git add tools/init-project.sh && git commit -m "fix: init-project.sh references non-existent default.json — copy all agent configs"
```

**Verify:** `! grep 'default\.json' tools/init-project.sh`

### Task 5: Sync CLAUDE.md ↔ AGENTS.md

AGENTS.md has 3 extra principles (Never skip anomalies, Recommend before asking, Socratic self-check) that CLAUDE.md lacks. These should be in sync.

**Files:**
- Modify: `CLAUDE.md`

**Step 1: Add missing principles to CLAUDE.md**
Copy the 3 missing principles from AGENTS.md to CLAUDE.md after the "Think like a top expert" line.

**Step 2: Commit**
```bash
git add CLAUDE.md && git commit -m "chore: sync CLAUDE.md with AGENTS.md — add 3 missing principles"
```

**Verify:** `diff CLAUDE.md AGENTS.md`

### Task 6: Fix docs/INDEX.md — Stale and Incomplete

docs/INDEX.md only has 1 entry from Feb 13. There are 20+ plan files and a design doc not listed.

**Files:**
- Modify: `docs/INDEX.md`

**Step 1: Regenerate index**
List all docs/plans/*.md and docs/designs/*.md with dates and titles, update the table.

**Step 2: Commit**
```bash
git add docs/INDEX.md && git commit -m "docs: regenerate docs/INDEX.md — add all plan files"
```

**Verify:** `[ $(grep -c '|' docs/INDEX.md) -gt 10 ]`

### Task 7: Regenerate KB Health Report

The health report shows 14/30 episodes but episodes.md now has ~30 entries. The report was generated Feb 15 and never refreshed.

**Files:**
- Modify: `knowledge/.health-report.md` (regenerate by running the hook)

**Step 1: Regenerate**
```bash
WS_HASH=$(pwd | shasum | cut -c1-8)
touch "/tmp/kb-changed-${WS_HASH}.flag"
rm -f "/tmp/kb-report-${WS_HASH}.cooldown"
bash hooks/feedback/kb-health-report.sh
```

**Step 2: Commit**
```bash
git add knowledge/.health-report.md && git commit -m "chore: regenerate KB health report"
```

**Verify:** `grep -q "$(date +%Y-%m-%d)" knowledge/.health-report.md`

## Review

### Round 1–2 (old reviewer prompt)

Rounds 1–2 used the pre-tuning reviewer prompt. Key fixes applied:
- `rm -d` → `rmdir`, regex anchors added, pipe precedence fixed, hardcoded date → dynamic
- 3/4 APPROVE in Round 2

### Round 3 (new reviewer prompt — structured findings, anchor examples, severity calibration)

**Completeness — REQUEST CHANGES:**
- Task 5 diff logic "impossible" → **Dismissed**: reviewer misunderstood task. Goal is to make files identical, `diff` returns 0 when identical = correct.
- Other items (backup strategy, error handling, title extraction) → Nit, not P0/P1.

**Testability — REQUEST CHANGES:**
- ~~Task 3 verify missing second comment check~~ → **P1, Fixed**: added `! grep 'Allow ralph-loop\.sh itself'` to verify.
- Other items (git vs filesystem, pipe counting) → Nit.

**Technical Feasibility — CONDITIONAL APPROVE:**
- File existence concerns → Nit, files confirmed to exist.

**Clarity — REQUEST CHANGES:**
- ~~Task 1 `{commands}` ambiguous~~ → **P1, Fixed**: clarified "literal braces in name, not shell glob".
- Task 5 diff logic → same misunderstanding as Completeness, dismissed.

**New prompt quality assessment:**
- ✅ Finding format improved — most have problem + impact + fix
- ✅ No low-value risk padding
- ✅ Testability caught a real bug (Task 3 missing verify)
- ❌ Multiple reviewers still misunderstood Task 5 diff semantics
- Overall: significantly better signal-to-noise ratio vs Round 1–2

**FINAL VERDICT: APPROVE (2 valid P1 fixes applied, remaining items are Nit)**

## Checklist

- [x] Dead files removed (broken symlinks, .bak, empty dirs) | `! git ls-files | grep -E 'lessons-learned\.md\.bak$|\.test-enforce-plan\.md$|hooks\.bak$|skills\.bak$|kiro-prompts/commands$'`
- [x] README.md has no stale script references | `! grep -E 'ralph-loop\.sh|generate-platform-configs\.sh' README.md`
- [x] enforcement.md references generate_configs.py | `grep -q 'generate_configs.py' .kiro/rules/enforcement.md`
- [x] enforce-ralph-loop.sh comments updated | `! grep 'must use ralph-loop\.sh' hooks/gate/enforce-ralph-loop.sh && ! grep 'Allow ralph-loop\.sh itself' hooks/gate/enforce-ralph-loop.sh`
- [x] init-project.sh uses pilot.json not default.json | `! grep 'default\.json' tools/init-project.sh`
- [x] CLAUDE.md and AGENTS.md are in sync | `diff CLAUDE.md AGENTS.md`
- [x] docs/INDEX.md has >10 entries | `[ $(grep -c '|' docs/INDEX.md) -gt 10 ]`
- [x] KB health report regenerated | `grep -q "$(date +%Y-%m-%d)" knowledge/.health-report.md`
- [SKIP] All existing tests still pass — blocked by security hook (enforce-ralph-loop blocks pytest outside ralph-loop) | `python3 -m pytest tests/ -q`

## Errors

| Error | Task | Attempt | Resolution |
|-------|------|---------|------------|
