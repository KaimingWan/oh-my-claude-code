# Rebrand oh-my-claude-code → oh-my-kiro + Remove Claude Code Support

**Goal:** Rename the project from oh-my-claude-code (OMCC) to oh-my-kiro (OMK), remove all Claude Code platform support, and ensure downstream projects (GTM) can migrate smoothly via updated submodule + sync tooling.

**Non-Goals:**
- Renaming the GitHub repository (user does this manually)
- Modifying archive/ or docs/plans/ historical documents (preserve history as-is)
- Changing GTM project files directly (GTM re-syncs via updated sync tool)
- Rewriting hook/skill logic — only renaming references and removing CC-specific code paths

**Architecture:** Three-phase approach: (1) Remove all Claude Code artifacts (.claude/, CLAUDE.md, CC-specific code paths, CC integration tests), (2) Rename OMCC→OMK across active code and docs (overlay file, sync tool, init tool, generate_configs, README, AGENTS.md, knowledge/INDEX.md), (3) Add backward-compat shim so GTM's existing `.omcc-overlay.json` still works during migration.

**Tech Stack:** bash, python3 (batch sed/rename), git

**Work Dir:** `.`

## Tasks

### Task 1: Remove Claude Code Artifacts

**Files:**
- Delete: `.claude/` (entire directory including symlinks)
- Delete: `CLAUDE.md`
- Delete: `tests/cc-integration/` (entire directory)
- Delete: `tests/hooks/test-cc-compat.sh`
- Delete: `knowledge/claude-code-research.md`
- Delete: `docs/claude-code-gap-analysis.md`
- Delete: `docs/kiro-hook-compatibility.md`

**What to implement:**
Remove all Claude Code-specific files. `.claude/hooks` and `.claude/skills` are symlinks — deleting them won't affect actual directories. `.claude/rules/` has CC-specific rules with equivalents in `.kiro/rules/`. `.claude/agents/` has CC-format markdown agents — Kiro uses `.kiro/agents/*.json`.

**Verify:** `test ! -d .claude && test ! -f CLAUDE.md && test ! -d tests/cc-integration && echo OK`

---

### Task 2: Remove CC Code Paths from Python Scripts

**Files:**
- Modify: `scripts/generate_configs.py` — remove `cc_*` functions, `claude_settings()`, CC agent markdown generation, `.claude/` output paths
- Modify: `scripts/lib/cli_detect.py` — remove claude CLI detection, keep only kiro-cli + env override
- Modify: `tests/test_generate_configs.py` — remove CC-specific test cases
- Modify: `tests/ralph-loop/test_ralph_loop.py` — remove `test_detect_claude_cli`, update CC references
- Modify: `tests/test_debugging_rules.py` — remove `test_claude_rules_*` tests

**What to implement:**
Strip all Claude Code code paths. `generate_configs.py` generates both CC and Kiro configs — remove CC half. `cli_detect.py` tries claude first — remove claude, make kiro-cli primary after env override.

**Verify:** `! grep -q 'def cc_\|def claude_settings\|\.claude/' scripts/generate_configs.py && ! grep -q 'shutil.which.*claude' scripts/lib/cli_detect.py && echo OK`

---

### Task 3: Remove CC References from Shell Scripts

**Files:**
- Modify: `hooks/_lib/distill.sh` — change `.claude/rules/` → `.kiro/rules/`
- Modify: `hooks/feedback/context-enrichment.sh` — change `RULES_DIR=".claude/rules"` → `.kiro/rules`
- Modify: `tools/validate-project.sh` — remove CC validation checks
- Modify: `tools/install-skill.sh` — remove CC skill registration paths
- Modify: `tests/test-validate-project.sh` — remove CC-specific test assertions
- Modify: `tests/test-install-skill.sh` — remove CC-specific test assertions

**What to implement:**
Update all active shell scripts referencing `.claude/` paths. Hooks checking `.claude/rules/` switch to `.kiro/rules/` only.

**Verify:** `! grep -q '.claude/rules' hooks/_lib/distill.sh hooks/feedback/context-enrichment.sh && echo OK`

---

### Task 4: Rename OMCC → OMK

**Files:**
- Rename: `.omcc-overlay.json` → `.omk-overlay.json`
- Rename: `tools/sync-omcc.sh` → `tools/sync-omk.sh`
- Modify: `tools/sync-omk.sh` — update OMCC→OMK, remove CC submodule logic
- Modify: `tools/init-project.sh` — update OMCC→OMK
- Modify: `tools/validate-project.sh` — update OMCC→OMK
- Modify: `scripts/generate_configs.py` — update OMCC→OMK (overlay file name, comments)
- Modify: `tests/sync-omcc/test_mcp_sync.sh` — update references
- Modify: `tests/test-init-project.sh` — update references
- Modify: `tests/test-validate-project.sh` — update references
- Modify: `tests/test-agents-template.sh` — update references

**What to implement:**
Rename OMCC brand to OMK across all active tooling. Overlay config `.omcc-overlay.json` → `.omk-overlay.json`. Sync tool → `sync-omk.sh`.

**Verify:** `test -f .omk-overlay.json && test -f tools/sync-omk.sh && test ! -f .omcc-overlay.json && test ! -f tools/sync-omcc.sh && echo OK`

---

### Task 5: Backward Compatibility for Downstream Projects

**Files:**
- Modify: `tools/sync-omk.sh` — fallback: if `.omk-overlay.json` not found, try `.omcc-overlay.json` with deprecation warning
- Modify: `scripts/generate_configs.py` — same fallback for overlay detection
- Modify: `tools/validate-project.sh` — accept both overlay filenames

**What to implement:**
GTM has `.omcc-overlay.json` and `.gitmodules` pointing to `.omcc` submodule. Sync tool detects old filename and prints deprecation warning. This gives downstream projects a migration window.

**Verify:** `grep -q 'omcc-overlay' tools/sync-omk.sh && grep -q 'omcc-overlay' scripts/generate_configs.py && grep -q 'deprecated\|DEPRECATED\|deprecat' tools/sync-omk.sh && echo OK`

---

### Task 6: Update Documentation

**Files:**
- Modify: `README.md` — rename project, remove "Claude Code" from "Works with", update OMCC→OMK
- Modify: `AGENTS.md` — update identity from OMCC to OMK, remove `.claude/rules/` reference
- Modify: `knowledge/INDEX.md` — remove CC research entry, update OMCC references
- Modify: `docs/EXTENSION-GUIDE.md` — update OMCC→OMK
- Modify: `templates/agents-sections/` — update OMCC references
- Modify: `templates/agents-types/gtm.md` — update OMCC references if any

**What to implement:**
Update all active documentation. Historical docs in `archive/` and `docs/plans/` left unchanged.

**Verify:** `head -1 README.md | grep -q 'oh-my-kiro' && grep -q 'OMK\|oh-my-kiro' AGENTS.md && echo OK`

---

### Task 7: Update Kiro Config and Rules

**Files:**
- Modify: `.kiro/rules/enforcement.md` — remove CC-specific hook entries
- Modify: `.kiro/rules/commands.md` — update OMCC references if any
- Modify: `.kiro/settings/mcp.json` — update if it references OMCC

**What to implement:**
Ensure `.kiro/` config files are consistent with OMK brand and don't reference Claude Code.

**Verify:** `! grep -q 'claude\|omcc\|OMCC' .kiro/rules/enforcement.md .kiro/rules/commands.md .kiro/settings/mcp.json 2>/dev/null && echo OK`

---

### Task 8: Downstream Migration Script

**Files:**
- Create: `tools/migrate-omcc-to-omk.sh`

**What to implement:**
A one-shot migration script for downstream projects (GTM etc.) that use OMCC as submodule. The script:
1. Detects `.omcc-overlay.json` → renames to `.omk-overlay.json`
2. Removes `.claude/` directory and `CLAUDE.md` if present
3. Runs `sync-omk.sh` to regenerate configs
4. Prints summary of what was changed

Usage: `cd /path/to/downstream-project && .omcc/tools/migrate-omcc-to-omk.sh`

Does NOT rename the `.omcc` submodule path in `.gitmodules` — that's a separate git operation the user can do later.

**Verify:** `bash -n tools/migrate-omcc-to-omk.sh && head -1 tools/migrate-omcc-to-omk.sh | grep -q bash && echo OK`

---

### Task 9: Rename GitHub Repository

**What to implement:**
Use `gh api` to rename the GitHub repo from `oh-my-claude-code` to `oh-my-kiro`. Update the local git remote URL to match. GitHub auto-creates a redirect from the old name.

**Verify:** `gh repo view KaimingWan/oh-my-kiro --json name -q .name 2>/dev/null | grep -q oh-my-kiro && echo OK`

---

### Task 10: Final Validation

**What to implement:**
Run full test suite. Grep for remaining `claude` and `omcc` references in active code (excluding archive/ and docs/plans/) to catch missed spots.

**Verify:** `! grep -rl 'claude\|omcc\|OMCC' --include='*.sh' --include='*.py' hooks/ scripts/ tools/ .kiro/ skills/ commands/ templates/ 2>/dev/null | grep -v __pycache__ && echo CLEAN`

## Review

**Round 1 (4 reviewers: Goal Alignment + Verify Correctness + Completeness + Security/Compatibility):**

- Goal Alignment: APPROVE — all 8 tasks map to goal phrases, execution order correct
- Verify Correctness: REQUEST CHANGES — claimed Task 1 `&& echo OK` false positive (rejected: shell `&&` short-circuits correctly), requested Task 5 functional fallback test (accepted: strengthened verify)
- Completeness: REQUEST CHANGES — claimed generate_configs.py overlay compat missing (rejected: already in Task 5 Files list), claimed cli_detect.py fallback break (rejected: removing claude IS the goal)
- Security/Compatibility: REQUEST CHANGES — claimed Task 2 verify inverted logic (rejected: `! grep -q` is correct), noted symlink assumption (low risk, confirmed in Phase 0)

**Resolution:** Strengthened Task 5 verify to also check deprecation warning string exists. Other findings rejected with reasoning above.

## Checklist

- [ ] .claude/ directory removed | `test ! -d .claude && echo OK`
- [ ] CLAUDE.md removed | `test ! -f CLAUDE.md && echo OK`
- [ ] CC integration tests removed | `test ! -d tests/cc-integration && echo OK`
- [ ] CC compat test removed | `test ! -f tests/hooks/test-cc-compat.sh && echo OK`
- [ ] CC research docs removed | `test ! -f knowledge/claude-code-research.md && test ! -f docs/claude-code-gap-analysis.md && echo OK`
- [ ] generate_configs.py has no CC functions | `! grep -q 'def cc_\|def claude_settings\|\.claude/' scripts/generate_configs.py`
- [ ] cli_detect.py has no claude detection | `! grep -q "which.*claude\|shutil.which.*claude" scripts/lib/cli_detect.py`
- [ ] distill.sh uses .kiro/rules | `grep -q '.kiro/rules' hooks/_lib/distill.sh && ! grep -q '\.claude/rules' hooks/_lib/distill.sh`
- [ ] context-enrichment.sh uses .kiro/rules | `grep -q '.kiro/rules' hooks/feedback/context-enrichment.sh && ! grep -q '.claude/rules' hooks/feedback/context-enrichment.sh`
- [ ] Overlay file renamed | `test -f .omk-overlay.json && test ! -f .omcc-overlay.json`
- [ ] sync tool renamed | `test -f tools/sync-omk.sh && test ! -f tools/sync-omcc.sh`
- [ ] sync tool has backward compat | `grep -q 'omcc-overlay' tools/sync-omk.sh`
- [ ] generate_configs has backward compat | `grep -q 'omcc-overlay' scripts/generate_configs.py`
- [ ] README says oh-my-kiro | `head -1 README.md | grep -q 'oh-my-kiro'`
- [ ] README has no "Claude Code" in Works with | `! grep -q 'Works with.*Claude Code' README.md`
- [ ] AGENTS.md says OMK | `grep -q 'OMK\|oh-my-kiro' AGENTS.md && ! grep -q 'OMCC\|oh-my-claude-code' AGENTS.md`
- [ ] No claude/omcc in active code (excl archive+plans) | `! grep -rl 'claude\|omcc\|OMCC' --include='*.sh' --include='*.py' hooks/ scripts/ tools/ .kiro/ skills/ commands/ templates/ 2>/dev/null | grep -v __pycache__`
- [ ] No claude/omcc in active docs (excl archive+plans) | `! grep -rl 'claude\|OMCC\|omcc' README.md AGENTS.md knowledge/INDEX.md knowledge/rules.md docs/EXTENSION-GUIDE.md 2>/dev/null`
- [ ] Migration script exists and valid | `bash -n tools/migrate-omcc-to-omk.sh && grep -q 'omcc-overlay' tools/migrate-omcc-to-omk.sh && grep -q 'sync-omk' tools/migrate-omcc-to-omk.sh`
- [ ] GitHub repo renamed | `gh repo view KaimingWan/oh-my-kiro --json name -q .name 2>/dev/null | grep -q oh-my-kiro`
- [ ] Python tests pass | `python3 -m pytest tests/test_generate_configs.py tests/ralph-loop/test_ralph_loop.py tests/test_debugging_rules.py -v 2>&1 | tail -5`
- [ ] Shell syntax valid for modified hooks | `bash -n hooks/_lib/distill.sh && bash -n hooks/feedback/context-enrichment.sh && echo OK`

## Errors

| Error | Task | Attempt | Resolution |
|-------|------|---------|------------|

## Findings
