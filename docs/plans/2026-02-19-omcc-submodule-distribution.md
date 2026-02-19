# Plan: OMCC Submodule Distribution for china-poetry-app

> Goal: Apply oh-my-claude-code (OMCC) framework v3 to china-poetry-app (CPA) via git submodule + symlink, preserving all CPA project-specific knowledge/rules/skills, with one-command sync for future updates.

## Context

- OMCC: agent framework with hooks (security/gate/feedback), skills (planning/reviewing/etc), scripts (generate_configs.py, ralph_loop.py), commands, rules
- CPA: Expo/RN poetry app with project-specific knowledge (16 files), enforcement rules (R-BG/R-DEV/R-TRUTH/R-DESIGN/R-LAYOUT/R1-R10), hooks (5 scripts), skills (8 project-specific + 22 old Kiro built-in)
- CPA's old hooks are functionally superseded by OMCC's layered hook system
- CPA has project-specific skills in `.agents/skills/` (8 dirs: mobile-design, ios-simulator, etc.)

## Design Decisions

1. **Git submodule at `.omcc/`** — CPA repo stores only a commit pointer, not framework code
2. **Sub-directory symlinks** (not whole-directory) for hooks/ and skills/ — allows project-specific additions alongside framework content
3. **Whole-directory symlinks** for commands/ and scripts/ — no project customization needed
4. **`.omcc-overlay.json`** — declares project-specific hooks to merge into generated configs
5. **`generate_configs.py --project-root`** — new flag to support running from submodule context (change made in OMCC repo first, then available via submodule)
6. **`tools/sync-omcc.sh`** in CPA — one-command update: submodule pull + regenerate configs
7. **CPA keeps its own `plans/` directory** (not `docs/plans/`) — too much existing content to move
8. **AGENTS.md upgraded to v3 format** — preserves MoXun identity, adds Skill Routing + Authority Matrix

## Steps

### Task 1: [OMCC repo] Extend generate_configs.py with `--project-root` and overlay support

> This task modifies the OMCC framework itself. Must be committed to OMCC repo first, then CPA's submodule will pick it up.

**Do:**
- Add `--project-root PATH` argument: when set, use PATH as project root instead of `Path(__file__).parent.parent`
- Add `--overlay PATH` argument: read JSON file, merge extra hooks into generated configs
- Overlay format:
  ```json
  {
    "extra_hooks": {
      "preToolUse": [
        {"matcher": "fs_write", "command": "hooks/project/enforce-code-quality.sh"}
      ]
    },
    "extra_resources": [],
    "plans_dir": "plans"
  }
  ```
- When overlay has `extra_hooks`, append them to the appropriate hook arrays in all agent configs (both Kiro and Claude Code formats)
- Validation: overlay hooks must point to files that exist on disk (relative to project root)
- Backward compatible: running without `--project-root` or `--overlay` behaves exactly as before

**Test:** Run `python scripts/generate_configs.py` in OMCC repo — output unchanged. Run with `--project-root /tmp/test --overlay /tmp/test/overlay.json` — generates configs with merged hooks.

### Task 2: [CPA repo] Add submodule and create directory structure

**Do:**
- `git submodule add git@github.com:KaimingWan/oh-my-claude-code.git .omcc` in CPA
- Create `hooks/` directory with sub-directory symlinks:
  - `hooks/security → ../.omcc/hooks/security/`
  - `hooks/gate → ../.omcc/hooks/gate/`
  - `hooks/feedback → ../.omcc/hooks/feedback/`
  - `hooks/_lib → ../.omcc/hooks/_lib/`
  - `hooks/project/` — real directory for CPA-specific hooks
- Move `enforce-code-quality.sh` from `.kiro/hooks/` to `hooks/project/`
- Create symlinks: `commands → .omcc/commands`, `scripts → .omcc/scripts`
- Update `.kiro/hooks`: remove old symlink/dir, recreate as `ln -sf ../hooks .kiro/hooks`
- Update `.claude/hooks`: `ln -sf ../hooks .claude/hooks`
- Create `.claude/rules → .omcc/.claude/rules` (CPA doesn't have this, OMCC provides shell/workflow/subagent/security/debugging/testing/code-quality/git-workflow rules)
- Preserve `.kiro/settings/lsp.json` — do NOT touch `.kiro/settings/` directory
- Update CPA `.gitignore`: add `.omcc/**` exclusion for build tools (note: git submodule content is already not tracked by parent repo, but this prevents accidental `git add .omcc/`)

**Verify:** `ls -la hooks/security/block-dangerous.sh` shows content. `hooks/project/enforce-code-quality.sh` exists. `.kiro/settings/lsp.json` unchanged. `.claude/rules/shell.md` resolves.

### Task 3: [CPA repo] Migrate skills — framework symlinks + project-specific preservation

**Do:**
- Create top-level `skills/` directory
- Symlink OMCC framework skills: `skills/planning → ../.omcc/skills/planning/`, etc. for all 8 OMCC skills (planning, reviewing, verification, finishing, debugging, research, self-reflect, find-skills)
- Move CPA project-specific skills from `.agents/skills/` to `skills/` (real directories): mobile-design, ios-simulator-skill, code-review-expert, ios-testing-patterns, maestro-mobile-testing, mobile-ios-design, ui-ux-pro-max, xcodebuildmcp-cli
- Move CPA's `dialectical-review-gates` from `.kiro/skills/` to `skills/`
- Check `security-review` skill integrity before moving (may be empty directory)
- Remove old `.kiro/skills/` contents (22 old Kiro built-in skills superseded by OMCC)
- Recreate `.kiro/skills → ../skills`, `.claude/skills → ../skills`
- Remove `.agents/` directory (contents migrated)

**Verify:** `ls skills/planning/SKILL.md` resolves. `ls skills/mobile-design/` shows project content. `ls skills/ios-simulator-skill/` shows project content.

### Task 4: [CPA repo] Create `.omcc-overlay.json` and `tools/sync-omcc.sh`

**Do:**
- Create `.omcc-overlay.json` with CPA's project-specific hook (enforce-code-quality.sh)
- Create or update `tools/sync-omcc.sh`:
  ```bash
  #!/bin/bash
  set -e
  cd "$(git rev-parse --show-toplevel)"
  git submodule update --remote .omcc
  python3 .omcc/scripts/generate_configs.py --project-root . --overlay .omcc-overlay.json
  echo "✅ OMCC synced to $(cd .omcc && git rev-parse --short HEAD)"
  ```
- `chmod +x tools/sync-omcc.sh`

**Verify:** File exists and is executable.

### Task 5: [CPA repo] Generate configs and verify hook resolution

**Do:**
- Run `python3 .omcc/scripts/generate_configs.py --project-root . --overlay .omcc-overlay.json`
- Verify generated `.kiro/agents/default.json` contains:
  - All OMCC security hooks (block-dangerous, block-secrets, block-sed-json, block-outside-workspace)
  - All OMCC gate hooks (pre-write, enforce-ralph-loop)
  - All OMCC feedback hooks (correction-detect, session-init, context-enrichment, post-write, post-bash, verify-completion)
  - CPA's project hook (enforce-code-quality)
- Verify generated `.claude/settings.json` has equivalent Claude Code hook config
- Replace CPA's old minimal `.claude/settings.json` with generated version

**Verify:** `jq '.hooks.preToolUse[] | select(.command | contains("enforce-code-quality"))' .kiro/agents/default.json` returns a result. `jq '.hooks.preToolUse[] | select(.command | contains("block-dangerous"))' .kiro/agents/default.json` returns a result.

### Task 6: [CPA repo] Upgrade AGENTS.md to v3 format

**Do:**
- Rewrite CPA's `AGENTS.md` in OMCC v3 format:
  - Keep: MoXun Agent identity, 中文优先, 3 roles (Engineer/iOS QA/Design), knowledge retrieval, self-learning, end-to-end problem solving
  - Add: Skill Routing table (mapping OMCC skills + CPA project skills), Authority Matrix, Workflow section referencing OMCC skills
  - Remove: old 3-Layer Architecture header (replaced by v3 structure), old custom commands section (moved to commands/)
- Update `CLAUDE.md` to match (same content, different filename for Claude Code compatibility)

**Verify:** `wc -l AGENTS.md` ≤ 200 lines. File contains `## Skill Routing` and `## Authority Matrix` sections.

### Task 7: [CPA repo] Clean up old CPA agent artifacts

**Do:**
- Remove old hooks: `.kiro/hooks/deny-commands.sh`, `.kiro/hooks/enforce-research.sh`, `.kiro/hooks/three-rules-check.sh`, `.kiro/hooks/check-persist.sh`, `.kiro/hooks/violation-log.jsonl` (note: `.kiro/hooks` is now a symlink to `../hooks`, so these files should already be gone after Task 2; verify and clean up any remnants)
- Update `.kiro/rules/enforcement.md` "Implemented" table: replace old hook paths with new OMCC hook paths
- Old `.kiro/agents/default.json` replaced by generated version (Task 5)
- Verify `.kiro/rules/enforcement.md`, `.kiro/rules/reference.md`, `.kiro/rules/commands.md` are preserved (project-specific content)
- Verify `knowledge/` directory is completely untouched

**Verify:** `git diff --stat -- knowledge/` shows no changes. Old hook files don't exist. `.kiro/rules/enforcement.md` exists and contains R-BG rule.

### Task 8: [CPA repo] Verify symlink resolution for hooks with relative paths

**Do:**
- Test that hooks using `source "$(dirname "$0")/../_lib/common.sh"` resolve correctly through symlinks
- Symlink chain: `hooks/feedback/post-write.sh` → (symlink dir) → `.omcc/hooks/feedback/post-write.sh`. `dirname` returns `hooks/feedback/`, so `../_lib/` = `hooks/_lib/` which is a symlink to `.omcc/hooks/_lib/`. This should work.
- Test with proper JSON input: `echo '{"tool_name":"fs_write","tool_input":{"file_path":"test.txt","new_str":"x"}}' | bash hooks/feedback/post-write.sh 2>&1`
- If any hook fails to source _lib, debug the symlink chain

**Verify:** Hook scripts can source `_lib/common.sh` and `_lib/distill.sh` without "No such file" errors.

### Task 9: [CPA repo] End-to-end smoke test

**Do:**
- From CPA directory:
  1. `python3 -c "import json; json.load(open('.kiro/agents/default.json'))"` — valid JSON
  2. `python3 -c "import json; json.load(open('.claude/settings.json'))"` — valid JSON
  3. For each hook path in config: verify file exists and is executable
  4. For each skill in resources: verify SKILL.md exists
  5. `diff <(git show HEAD:knowledge/INDEX.md) knowledge/INDEX.md` — unchanged (or `git status --porcelain -- knowledge/` shows clean)
  6. `git status --porcelain -- moxun/ worker/` — empty (no business code changes)

**Verify:** All 6 checks pass. Zero changes to business code.

## Review

### Round 1 (4 reviewers, 2026-02-19)

**Findings addressed:**
- ✅ Task 3 (now Task 1) clarified as OMCC repo change, committed upstream first
- ✅ `.gitignore` update added to Task 2
- ✅ Task 8 verify command fixed with proper JSON input
- ✅ Task 9 `git diff` replaced with `git status --porcelain`
- ✅ `.kiro/settings/lsp.json` preservation explicitly noted in Task 2
- ✅ `.claude/rules/` symlink creation added to Task 2
- ✅ `security-review` skill integrity check added to Task 3
- ✅ `.claude/settings.json` replacement clarified in Task 5

## Checklist

- [ ] `generate_configs.py` supports `--project-root` and `--overlay` flags (backward compatible)
- [ ] Git submodule `.omcc/` added, CPA repo only stores commit pointer
- [ ] `hooks/` directory has sub-directory symlinks to `.omcc/hooks/{security,gate,feedback,_lib}/` + `hooks/project/` for CPA-specific hooks
- [ ] `skills/` directory has symlinks to OMCC skills + real directories for CPA project skills
- [ ] `commands → .omcc/commands` and `scripts → .omcc/scripts` symlinks work
- [ ] `.omcc-overlay.json` declares CPA's project-specific hooks
- [ ] `tools/sync-omcc.sh` runs successfully: submodule update + config regeneration
- [ ] Generated `.kiro/agents/default.json` contains both OMCC and CPA hooks
- [ ] Generated `.claude/settings.json` contains equivalent hook config
- [ ] `.claude/rules/` available via symlink to OMCC
- [ ] `.kiro/settings/lsp.json` preserved
- [ ] `AGENTS.md` upgraded to v3 format with MoXun identity preserved
- [ ] Old CPA hooks removed (deny-commands, enforce-research, three-rules-check, check-persist)
- [ ] `.kiro/rules/enforcement.md` updated with new hook paths, project rules preserved
- [ ] `knowledge/` directory completely untouched
- [ ] No business code (moxun/, worker/) modified
- [ ] Hook scripts resolve `_lib/` correctly through symlinks
- [ ] CPA `.gitignore` updated
