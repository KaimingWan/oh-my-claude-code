# GTM ↔ OMCC Framework Integration Plan

**Goal:** Integrate OMCC framework into the existing gtm project via git submodule, giving gtm access to OMCC's hooks, skills, config generation, and self-learning capabilities — without breaking gtm's existing knowledge base, AGENTS.md business content, or operational workflows.

**Non-Goals:**
- Rewriting gtm's AGENTS.md business sections (identity, roles, 四种角色, 客户优先级, 邮件规则 etc.)
- Modifying gtm's knowledge/ directory content
- Migrating gtm's 103 third-party skills out of `.agents/skills/`
- Adding git-lfs or other large-file handling

**Architecture:** Git init gtm → add OMCC as `.omcc/` submodule → create `.omcc-overlay.json` with gtm-specific hooks/skills → run `sync-omcc.sh` to generate agent configs, symlink hooks/skills/scripts → inject OMCC shared sections into AGENTS.md via `<!-- BEGIN/END OMCC -->` markers → clean up redundant IDE directories.

**Tech Stack:** bash, git submodule, Python (generate_configs.py), jq

## Tasks

### Task 1: Git Init + .gitignore

**Files:**
- Create: `.gitignore` (overwrite existing)
- Create: `.git/` (via git init)

**What to implement:**

Write comprehensive .gitignore (excluding tmp/, .firecrawl/, IDE dirs, caches, .DS_Store), then `git init` and make initial commit with all existing content.

**Verify:**
```bash
cd /Users/wanshao/project/gtm && git rev-parse --is-inside-work-tree && git log --oneline -1
```
Expected: `true` + initial commit message

---

### Task 2: Add OMCC as Submodule

**Files:**
- Create: `.omcc` (submodule)
- Create: `.gitmodules`

**What to implement:**

Add OMCC as git submodule at `.omcc/` using local path `/Users/wanshao/project/oh-my-claude-code`. Commit.

**Verify:**
```bash
cd /Users/wanshao/project/gtm && test -f .omcc/AGENTS.md && test -f .omcc/scripts/generate_configs.py && echo OK
```
Expected: `OK`

---

### Task 3: Set Up Hooks Directory + Create Overlay

**Files:**
- Create: `hooks/` directory (with OMCC hooks copied + project hooks)
- Create: `hooks/project/` directory
- Move: `.kiro/hooks/*.sh` → `hooks/project/*.sh`
- Create: `.omcc-overlay.json`
- Symlink: `.kiro/hooks` → `../hooks`

**What to implement:**

1. Copy OMCC hooks into project's `hooks/` directory (mirroring init-project.sh behavior: `cp -r .omcc/hooks/* hooks/`). This gives the project its own copy of OMCC hooks that generate_configs.py can reference.
2. Create `hooks/project/` and move gtm's 3 existing hooks there (three-rules-check.sh, enforce-research.sh, check-persist.sh). Drop `block-dangerous-commands.sh` (OMCC's `security/block-dangerous.sh` is a superset).
3. Remove old `.kiro/hooks` directory, recreate as symlink: `ln -sf ../hooks .kiro/hooks`.
4. Create `.omcc-overlay.json` declaring gtm's 5 custom skills and 3 project-specific hooks.

Error handling:
- If `.kiro/hooks` is already a symlink, remove it before recreating.
- If `.kiro/hooks/*.sh` doesn't exist (already moved), skip move step gracefully.

**Verify:**
```bash
cd /Users/wanshao/project/gtm && test -f hooks/project/three-rules-check.sh && test -f hooks/security/block-dangerous.sh && test -L .kiro/hooks && python3 -c "import json; d=json.load(open('.omcc-overlay.json')); assert len(d['extra_skills'])==5; assert len(d['extra_hooks'])==3; print('OK')"
```
Expected: `OK`

---

### Task 4: Run sync-omcc.sh + Generate Configs

**Files:**
- Symlink: `scripts/` → `.omcc/scripts`
- Symlink: `commands/` → `.omcc/commands`
- Symlink: `.kiro/prompts` → `../commands`
- Generate: `.kiro/agents/*.json` (5 agent configs with merged hooks)
- Sync: `.kiro/rules/` (new files from OMCC, existing files preserved)
- Create: `docs/plans/`

**What to implement:**

Run `bash .omcc/tools/sync-omcc.sh .` which will:
1. Detect `.gitmodules` with OMCC submodule
2. Validate overlay (`.omcc-overlay.json`)
3. Run `generate_configs.py --project-root . --skip-validate --overlay .omcc-overlay.json` → generates `.kiro/agents/*.json` with OMCC hooks + overlay hooks merged
4. Create symlinks: `commands/` → `.omcc/commands`, `scripts/` → `.omcc/scripts`, `.kiro/prompts` → `../commands`
5. Sync `.kiro/rules/` files from OMCC (skip files that already exist in project)
6. Ensure `docs/plans/`

Note: `--skip-validate` is needed because generate_configs.py's validate() checks hooks against enforcement.md in OMCC root, not in the project. The overlay hooks are validated separately by load_overlay().

**Verify:**
```bash
cd /Users/wanshao/project/gtm && test -f .kiro/agents/default.json && jq -e '.hooks.userPromptSubmit[] | select(.command | contains("three-rules-check"))' .kiro/agents/default.json > /dev/null && echo OK
```
Expected: `OK`

---

### Task 5: Inject OMCC Shared Sections into AGENTS.md

**Files:**
- Modify: `AGENTS.md`

**What to implement:**

Insert 4 OMCC shared sections into gtm's AGENTS.md using `<!-- BEGIN/END OMCC -->` markers:
- PRINCIPLES — after section 0 (纲领自审), before section 1 (身份与语言)
- WORKFLOW — after section 7 (工作流), augmenting with OMCC's Skill Routing table
- SELF-LEARNING — replace section 9 (自学习 kiro-reflect) with OMCC's standardized version
- AUTHORITY — after section 8 (Kiro 特殊处理)

Preserve ALL gtm-specific content: identity, 四种角色, 客户优先级, 邮件规则, 复利原则, 三大铁律, 第四铁律, 工作流 SOP, 自定义命令, 更新日志.

**Verify:**
```bash
cd /Users/wanshao/project/gtm && test $(grep -c 'BEGIN OMCC' AGENTS.md) -ge 4 && grep -q 'AutoMQ GTM Engine' AGENTS.md && grep -q '客户优先级' AGENTS.md && echo OK
```
Expected: `OK`

---

### Task 6: Clean Up Redundant IDE Directories

**Files:**
- Remove: `.cursor/`, `.gemini/`, `.trae/`, `.opencode/`, `.claude/`, `.agent/`

**What to implement:**

Remove 6 redundant IDE directories. These are already in `.gitignore`. Only `.kiro/` is kept.

**Verify:**
```bash
cd /Users/wanshao/project/gtm && ! ls -d .cursor .gemini .trae .opencode .claude .agent 2>/dev/null && echo Clean
```
Expected: `Clean`

---

### Task 7: Rebuild .kiro/skills Symlinks

**Files:**
- Rebuild: `.kiro/skills/` symlinks

**What to implement:**

Ensure `.kiro/skills/` contains symlinks to three sources:
1. OMCC framework skills (8): `../../.omcc/skills/*`
2. Third-party skills (103): `../../.agents/skills/*`
3. GTM custom skills (5): already real directories in `.kiro/skills/`

If sync created `.kiro/skills` as a symlink to `skills/`, remove it and recreate as a directory with proper symlinks.

Handle naming conflicts: gtm's `research` skill (Tavily-based) vs OMCC's `research` skill — keep gtm's version since it's customized for gtm's multi-level search strategy.

**Verify:**
```bash
cd /Users/wanshao/project/gtm && test $(ls .kiro/skills/ | wc -l) -ge 110 && test -d .kiro/skills/content-ideation && echo OK
```
Expected: `OK`

---

### Task 8: Final Commit + Validation

**Files:**
- Commit all changes

**What to implement:**

Stage and commit all integration changes. Run full validation: git status clean, agent configs exist, hooks work, OMCC markers present, knowledge untouched, no IDE dirs.

**Verify:**
```bash
cd /Users/wanshao/project/gtm && git status --porcelain | wc -l | grep -q 0 && echo OK
```
Expected: `OK`

---

## Review
<!-- Reviewer writes here -->

## Errors

| Error | Task | Attempt | Resolution |
|-------|------|---------|------------|

## Findings

- gtm's `block-dangerous-commands.sh` is a subset of OMCC's `security/block-dangerous.sh` — safe to drop
- gtm's `kiro-reflect` skill overlaps with OMCC's `self-reflect` skill — keep both (gtm's is customized for three-layer sync)
- gtm's `research` skill (Tavily-based) is different from OMCC's `research` skill — keep gtm's as project-specific
- Self-learning capability is delivered via: (a) OMCC hooks `correction-detect.sh` + `context-enrichment.sh` in agent configs, (b) OMCC `self-reflect` skill available via skills symlink, (c) OMCC SELF-LEARNING section injected into AGENTS.md, (d) gtm's own `kiro-reflect` skill preserved as project-specific enhancement

## Checklist

- [x] gtm is a git repo with initial commit | `cd /Users/wanshao/project/gtm && git rev-parse --is-inside-work-tree`
- [x] OMCC submodule exists at .omcc/ | `cd /Users/wanshao/project/gtm && test -f .omcc/AGENTS.md && echo OK`
- [x] .omcc-overlay.json is valid | `cd /Users/wanshao/project/gtm && python3 -c "import json; d=json.load(open('.omcc-overlay.json')); assert 'extra_skills' in d and 'extra_hooks' in d; print('OK')"`
- [x] Agent configs generated (5 files) | `cd /Users/wanshao/project/gtm && ls .kiro/agents/*.json 2>/dev/null | wc -l | grep -q 5 && echo OK`
- [x] Overlay hooks merged into default.json | `cd /Users/wanshao/project/gtm && jq -e '.hooks.userPromptSubmit[] | select(.command | contains("three-rules-check"))' .kiro/agents/default.json > /dev/null`
- [x] OMCC shared sections in AGENTS.md | `cd /Users/wanshao/project/gtm && test $(grep -c 'BEGIN OMCC' AGENTS.md) -ge 4 && echo OK`
- [x] No redundant IDE directories | `cd /Users/wanshao/project/gtm && ! ls -d .cursor .gemini .trae .opencode .claude .agent 2>/dev/null`
- [x] Knowledge directory untouched | `cd /Users/wanshao/project/gtm && test -f knowledge/INDEX.md && test -f knowledge/active-deals/INDEX.md && echo OK`
- [x] AGENTS.md business content preserved | `cd /Users/wanshao/project/gtm && grep -q 'AutoMQ GTM Engine' AGENTS.md && grep -q '客户优先级' AGENTS.md && echo OK`
- [x] Skills directory has OMCC + third-party + custom | `cd /Users/wanshao/project/gtm && test $(ls .kiro/skills/ | wc -l) -ge 110 && echo OK`
- [x] .gitignore excludes tmp/, .firecrawl/, IDE dirs | `cd /Users/wanshao/project/gtm && grep -q 'tmp/' .gitignore && grep -q '.firecrawl/' .gitignore && grep -q '.cursor/' .gitignore && echo OK`
- [x] Project hooks moved to hooks/project/ | `cd /Users/wanshao/project/gtm && test -f hooks/project/three-rules-check.sh && echo OK`
- [x] OMCC hooks copied to hooks/ | `cd /Users/wanshao/project/gtm && test -f hooks/security/block-dangerous.sh && test -f hooks/feedback/context-enrichment.sh && echo OK`
- [x] .kiro/hooks is symlink to ../hooks | `cd /Users/wanshao/project/gtm && test -L .kiro/hooks && echo OK`
