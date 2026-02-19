# Extension Points Implementation Plan

**Goal:** Enable domain-specific projects (iOS, Java, GTM) to extend the OMCC framework via 5 extension points (skills, hooks, knowledge, rules, AGENTS.md) with automated validation to ensure correctness.

**Non-Goals:**
- Implementing the submodule distribution itself (covered by `2026-02-19-omcc-submodule-distribution.md`)
- Modifying downstream projects (CPA, automqbox, GTM) — this plan only changes the OMCC framework repo
- Skill override/replacement mechanism (not needed per research)
- Plugin interface abstractions (OMCC is config-driven, not code-driven)

**Architecture:** Extend `generate_configs.py` to read `.omcc-overlay.json` with `extra_skills` + `extra_hooks` fields and merge them into generated agent configs. Provide `tools/validate-project.sh` as a hard gate before config generation. Provide `tools/install-skill.sh` to bridge `npx skills` ecosystem with OMCC overlay. Provide `templates/agents-sections/` for AGENTS.md layered inheritance. Update `tools/init-project.sh` to accept `--type` and assemble AGENTS.md from sections.

**Tech Stack:** Python (generate_configs.py), Bash (validate, install-skill, init-project, sync-omcc)

## Tasks

### Task 1: Extend generate_configs.py with overlay support

**Files:**
- Modify: `scripts/generate_configs.py`
- Test: `tests/test_generate_configs.py`

**What to implement:**
- Add `argparse` with `--project-root PATH` and `--overlay PATH` optional args
- Add `--skip-validate` flag to skip `validate()` (needed when running with `--project-root` pointing to a project dir that doesn't have OMCC hooks on disk)
- When `--project-root` set, use as PROJECT_ROOT instead of `Path(__file__).parent.parent`
- When `--overlay` set, read JSON, validate `extra_skills` paths have SKILL.md, validate `extra_hooks` command paths exist
- `_main_agent_resources()` accepts optional `extra_skills` list, appends `skill://{path}/SKILL.md`
- Agent builders accept optional `extra_hooks` dict, append to hook arrays
- Backward compatible: no args = current behavior

**Verify:** `python3 -m pytest tests/test_generate_configs.py -v`

### Task 2: Create validate-project.sh

**Files:**
- Create: `tools/validate-project.sh`
- Test: `tests/test-validate-project.sh`

**What to implement:**
- Accept project root as $1 (default: current dir)
- Error checks (exit 1): E1 overlay missing/invalid JSON, E2 extra_skills path missing SKILL.md, E3 extra_hooks command missing/not executable, E4 extra_hooks invalid event name, E5 project skill name conflicts framework skill, E6 AGENTS.md missing BEGIN/END markers, E7 key symlinks broken, E8 knowledge/INDEX.md missing/empty
- Warning checks (exit 0): W1 SKILL.md missing frontmatter, W2 extra_skills not in Skill Routing, W3 project hook name similar to framework, W4 knowledge file >50KB, W5 AGENTS.md >200 lines

**Verify:** `bash tests/test-validate-project.sh`

### Task 3: Create AGENTS.md section templates

**Files:**
- Create: `templates/agents-sections/principles.md`
- Create: `templates/agents-sections/workflow.md`
- Create: `templates/agents-sections/self-learning.md`
- Create: `templates/agents-sections/authority.md`
- Create: `templates/agents-types/coding.md`
- Create: `templates/agents-types/gtm.md`
- Test: `tests/test-agents-template.sh`

**What to implement:**
- Extract from current AGENTS.md into concise sections with `<!-- BEGIN/END OMCC X -->` markers
- Type templates provide Identity/Roles/Domain Rules skeleton
- Total assembled < 200 lines

**Verify:** `bash tests/test-agents-template.sh`

### Task 4: Update init-project.sh with --type and overlay scaffolding

**Files:**
- Modify: `tools/init-project.sh`
- Test: `tests/test-init-project.sh`

**What to implement:**
- Parse `--type {coding|gtm}` argument (default: coding)
- Assemble AGENTS.md from type template + section templates
- Guard: if templates/ dir not found (running outside OMCC context), fall back to copying plain AGENTS.md as before
- Create empty `.omcc-overlay.json`
- Copy `docs/EXTENSION-GUIDE.md`
- Create `hooks/project/` directory
- Backward compatible without `--type`

**Verify:** `bash tests/test-init-project.sh`

### Task 5: Create install-skill.sh and sync-omcc.sh

**Files:**
- Create: `tools/install-skill.sh`
- Create: `tools/sync-omcc.sh`
- Test: `tests/test-install-skill.sh`

**What to implement:**
- `install-skill.sh --register-only PROJECT_ROOT SKILL_PATH`: add to overlay JSON
- `install-skill.sh SOURCE`: npx skills add → move to skills/ → register → sync
- `sync-omcc.sh`: submodule update → validate → generate_configs → update AGENTS.md framework sections

**Verify:** `bash tests/test-install-skill.sh`

### Task 6: Create EXTENSION-GUIDE.md

**Files:**
- Create: `docs/EXTENSION-GUIDE.md`

**What to implement:**
- Concise speed-reference (< 60 lines): add skill, add hook, install community skill, validation, don'ts

**Verify:** `wc -l docs/EXTENSION-GUIDE.md | awk '{exit ($1 > 60)}'`

## Review

### Round 1 (4 reviewers: Goal Alignment, Verify Correctness, Completeness, Technical Feasibility)

**Findings addressed:**
- ✅ Checklist #1 verify command replaced: `python3 scripts/generate_configs.py && echo $?` → `python3 -m pytest tests/test_generate_configs.py::test_no_overlay_backward_compatible -v` (old command couldn't distinguish overlay working vs not implemented)
- ✅ Task 1 tests: must pass `--skip-validate` flag or set env var to skip `validate()` which requires hooks/ and enforcement.md on disk (tmp_path won't have these)
- ✅ Task 4: added guard for missing templates/ directory in init-project.sh
- ✅ Task 2 tests: added trap-based cleanup for test failure paths

### Round 2 (2 reviewers: Goal Alignment, Verify Correctness)

- Goal Alignment: APPROVE — all tasks map to goal, coverage complete
- Verify Correctness: REQUEST CHANGES — ~~reviewer checked current code for implementation, but this is a plan (tests created during execution, not before)~~ Rejected: misunderstood plan review scope

**Final verdict: APPROVE (Round 1 fixes verified, Round 2 false reject resolved)**

## Checklist

- [ ] generate_configs.py --project-root --overlay backward compatible | `python3 -m pytest tests/test_generate_configs.py::test_no_overlay_backward_compatible -v`
- [ ] overlay extra_skills merged into resources | `python3 -m pytest tests/test_generate_configs.py::test_overlay_extra_skills -v`
- [ ] overlay extra_hooks merged into hooks | `python3 -m pytest tests/test_generate_configs.py::test_overlay_extra_hooks -v`
- [ ] invalid overlay skill path rejected | `python3 -m pytest tests/test_generate_configs.py::test_overlay_invalid_skill_path -v`
- [ ] validate catches errors E1,E2,E8 | `bash tests/test-validate-project.sh`
- [ ] validate reports warning W1 | `bash tests/test-validate-project.sh`
- [ ] section templates exist with markers | `bash tests/test-agents-template.sh`
- [ ] assembled AGENTS.md under 200 lines | `bash tests/test-agents-template.sh`
- [ ] init --type coding correct output | `bash tests/test-init-project.sh`
- [ ] init --type gtm correct output | `bash tests/test-init-project.sh`
- [ ] init creates .omcc-overlay.json | `bash tests/test-init-project.sh`
- [ ] install-skill registers to overlay | `bash tests/test-install-skill.sh`
- [ ] sync-omcc calls validate before generate | `bash tests/test-install-skill.sh`
- [ ] EXTENSION-GUIDE.md under 60 lines | `wc -l docs/EXTENSION-GUIDE.md | awk '{exit ($1 > 60)}'`
- [ ] 回归测试通过 | `python3 -m pytest tests/ralph-loop/ -v`

## Errors

| Error | Task | Attempt | Resolution |
|-------|------|---------|------------|
