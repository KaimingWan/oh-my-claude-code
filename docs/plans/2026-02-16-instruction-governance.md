# Instruction Governance Redesign

**Goal:** Redesign CLAUDE.md/AGENTS.md governance with clear layering, write protection, content improvement, and clean separation of responsibilities.

**Architecture:** Three-layer instruction system: CLAUDE.md (identity + principles + workflow), `.claude/rules/` (topic-specific operational rules), knowledge/rules.md (agent-learned rules as staging area). Hook-enforced write protection. context-enrichment split into 3 single-responsibility scripts.

**Tech Stack:** Bash hooks, Markdown, jq

## Research Findings

Key findings from deep research (Anthropic official docs + community + GitHub issues):

1. **CLAUDE.md is advisory, hooks are deterministic** — Anthropic official. Source: docs.anthropic.com/en/docs/claude-code/best-practices
2. **CLAUDE.md < 500 lines** — "Bloated CLAUDE.md files cause Claude to ignore your actual instructions"
3. **Context decay is a known problem** — GitHub issues #18660 #23696 #15331 #21119. Model drifts from instructions as conversation grows.
4. **"没有 hook 强制的步骤 agent 就会跳过"** — Already in knowledge/rules.md, confirmed by research.
5. **Skill loading**: descriptions always loaded (low cost), full content on-demand. `disable-model-invocation: true` = zero cost until invoked.
6. **Authority Matrix pattern** (Yuki Capital): three-tier permission system for agent autonomy boundaries.
7. **Hook cost**: zero context, but has execution time and maintenance overhead. Only use for high-frequency violations with serious consequences.

## Rollback Strategy

All changes are file-level (markdown + shell scripts). Rollback = `git checkout HEAD~N -- <files>`. No database, no external state. Safe to revert any individual task.

## Tasks

### Task 0: Backup Current State

**Files:** None created, git handles it.

**Step 1:** Commit current state before starting: `git add -A && git commit -m "chore: snapshot before instruction governance redesign"`
**Step 2:** Tag for easy rollback: `git tag pre-governance-redesign`

**Verify:** `git tag | grep -q pre-governance-redesign`

### Task 1: Write Protection Hook for Instruction Files

**⚠️ Execution order dependency:** Task 1 的 hook 生效后会拦截 Task 2-3 对 CLAUDE.md 和 `.claude/rules/` 的修改。执行 Task 2-3 时需要 `touch .skip-instruction-guard`，完成后 `rm .skip-instruction-guard`。

**Files:**
- Modify: `hooks/gate/pre-write.sh`
- Create: `tests/instruction-guard/test-write-protection.sh`

**Step 1: Write failing test**
```bash
#!/bin/bash
# test-write-protection.sh
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
PASS=0; FAIL=0
run() {
  local desc="$1" input="$2" expect="$3"
  local rc=0; echo "$input" | bash hooks/gate/pre-write.sh >/dev/null 2>&1 || rc=$?
  if [ "$rc" -eq "$expect" ]; then echo "PASS: $desc"; PASS=$((PASS+1))
  else echo "FAIL: $desc (got $rc, want $expect)"; FAIL=$((FAIL+1)); fi
}
run "CLAUDE.md blocked" '{"tool_name":"fs_write","tool_input":{"file_path":"CLAUDE.md","command":"str_replace","new_str":"x"}}' 2
run "AGENTS.md blocked" '{"tool_name":"fs_write","tool_input":{"file_path":"AGENTS.md","command":"str_replace","new_str":"x"}}' 2
run "knowledge/rules.md blocked" '{"tool_name":"fs_write","tool_input":{"file_path":"knowledge/rules.md","command":"str_replace","new_str":"x"}}' 2
run ".claude/rules/ blocked" '{"tool_name":"fs_write","tool_input":{"file_path":".claude/rules/security.md","command":"create","new_str":"x"}}' 2
run ".kiro/rules/ blocked" '{"tool_name":"fs_write","tool_input":{"file_path":".kiro/rules/enforcement.md","command":"str_replace","new_str":"x"}}' 2
run "normal file allowed" '{"tool_name":"fs_write","tool_input":{"file_path":"scripts/test.sh","command":"create","new_str":"#!/bin/bash"}}' 0
run "episodes.md allowed" '{"tool_name":"fs_write","tool_input":{"file_path":"knowledge/episodes.md","command":"str_replace","new_str":"x"}}' 0
run "plan file allowed" '{"tool_name":"fs_write","tool_input":{"file_path":"docs/plans/test.md","command":"create","new_str":"x"}}' 0
run "skip guard override" 'touch .skip-instruction-guard && echo ok' 0  # tested manually
echo "Results: $PASS passed, $FAIL failed"; [ "$FAIL" -eq 0 ]
```

**Step 2: Run test — verify it fails**
Run: `bash tests/instruction-guard/test-write-protection.sh`
Expected: FAIL

**Step 3: Write minimal implementation**
Add `gate_instruction_files` function to `hooks/gate/pre-write.sh` as Phase 0, before existing `gate_check`:

```bash
gate_instruction_files() {
  case "$FILE" in
    CLAUDE.md|./CLAUDE.md|AGENTS.md|./AGENTS.md) ;;
    knowledge/rules.md|./knowledge/rules.md) ;;
    .claude/rules/*|.kiro/rules/*) ;;
    *) return 0 ;;
  esac
  case "$FILE" in *episodes.md) return 0 ;; esac
  [ -f ".skip-instruction-guard" ] && return 0
  hook_block "🚫 BLOCKED: Cannot modify instruction file: $FILE
Human-maintained only. Use @reflect for learnings → episodes.md."
}
```

Add `gate_instruction_files` call before `gate_check` in the execute section.

**Step 4: Run test — verify it passes**
Run: `bash tests/instruction-guard/test-write-protection.sh`
Expected: PASS

**Verify:** `bash tests/instruction-guard/test-write-protection.sh`

### Task 2: Rewrite CLAUDE.md Content

**Files:**
- Rewrite: `CLAUDE.md`
- Sync: `AGENTS.md`

**New CLAUDE.md content:**

```markdown
# Agent Framework v3

## Identity
- Agent for this project. English unless user requests otherwise.

## Principles
- Evidence before claims（任何完成声明前必须有验证证据，enforced by stop hook）
- As code（能代码化就不靠文字约束）
- TDD driven（测试驱动开发）
- No hallucination（必须引用来源，不确定就调研，不要信口开河）
- Fail closed（检测失败时拒绝，不放行）
- Minimal context, single source of truth（优先低 context 开销方案，信息只在一处维护）
- End-to-end autonomy（目标明确时独立端到端完成，不中断问人。遇到问题自己调研解决，主动克服障碍，直到拿到最终结果）
- Think like a top expert（深度广度充分，周全严谨细致高效，不要浅尝辄止）

## Workflow
- Explore → Plan → Code（先调研，再计划，再编码）
- 复杂任务先 interview，不要假设

## Authority Matrix
- Agent 自主：读文件、跑测试、探索代码、web search
- 需用户确认：改 plan 方向、跳过 skill 流程、git push
- 仅人操作：修改 CLAUDE.md / .claude/rules/（hook enforced）

## Skill Routing

| 场景 | Skill | 触发方式 |
|------|-------|---------|
| 规划/设计 | brainstorming → planning | `@plan` 命令 |
| 执行计划 | planning + ralph loop | `@execute` 命令 |
| Code Review | reviewing | `@review` 命令 |
| 调试 | debugging | rules.md 自动注入 |
| 调研 | research | `@research` 命令 |
| 完成前验证 | verification | Stop hook 自动 |
| 分支收尾 | finishing | planning 完成后 |
| 纠正/学习 | self-reflect | context-enrichment 检测 |
| 发现 skill | find-skills | 用户询问时 |

## Knowledge Retrieval
- Question → knowledge/INDEX.md → topic indexes → source docs

## Self-Learning
- 检测到纠正 → 写入 episodes.md
- 输出: `📝 Learning captured: '[preview]' → [target file]`

## Enforcement
- 硬拦截规则见 hooks/gate/ 和 hooks/security/
- 详细规则见 .claude/rules/ 或 .kiro/rules/
```

**Step 1:** Write new CLAUDE.md with above content
**Step 2:** Copy to AGENTS.md via `generate-platform-configs.sh` (single source — script reads CLAUDE.md and writes AGENTS.md, never manual copy)
**Step 3:** Verify no Shell Safety section remains, no duplication with `.claude/rules/`

**Verify:** `! grep -q '## Shell Safety' CLAUDE.md && grep -q '## Principles' CLAUDE.md && grep -q '## Authority Matrix' CLAUDE.md && diff CLAUDE.md AGENTS.md`

### Task 3: Expand `.claude/rules/` with Migrated Rules

**Files:**
- Create: `.claude/rules/shell.md`
- Create: `.claude/rules/workflow.md`
- Create: `.claude/rules/subagent.md`
- Create: `.claude/rules/debugging.md`
- Modify: `.claude/rules/security.md`
- Modify: `knowledge/rules.md`

**Layering principle:**
- `.claude/rules/` = human-designed operational rules, one-line principles + specific guidance
- `knowledge/rules.md` = agent-learned rules from episodes (staging area)
- No verbatim duplication between layers. Agent rules = principles, knowledge rules = operational details.

**File header template for each `.claude/rules/` file:**
```markdown
# [Topic] Rules
# Layer: Agent Rule (top-level principles + operational rules)
# Maintained by: humans only (hook enforced)
# Boundary: universal rules, not project-specific learnings
```

**Step 1:** Create `.claude/rules/shell.md` — migrate from knowledge/rules.md section `## [shell, json, jq, bash, stat, sed, awk, gnu, bsd, yaml, xml]` (all 5 rules)
**Step 2:** Create `.claude/rules/workflow.md` — migrate from knowledge/rules.md section `## [workflow, plan, review, skill, refactor, verify, test, commit]` (rules 1-9, the human-designed ones; leave rules 10-13 which are research findings)
**Step 3:** Create `.claude/rules/subagent.md` — migrate from knowledge/rules.md section `## [subagent, mcp, kiro, delegate, capability, tool]` (all 2 rules)
**Step 4:** Create `.claude/rules/debugging.md` — migrate from knowledge/rules.md section `## [debugging, bug, error, failure, fix, broken]` (all 3 rules)
**Step 5:** Expand `.claude/rules/security.md` — merge from knowledge/rules.md section `## [security, hook, injection, workspace, sandbox, secret]` (all 2 rules)
**Step 6:** Clean knowledge/rules.md — remove all migrated sections. Keep only rules 10-13 from workflow section (research findings not yet promoted) and any future agent-discovered rules. Update file header to reflect staging area role. **Important:** Do step 6 only after verifying all `.claude/rules/` files from steps 1-5 exist and have correct content. If any step 1-5 failed, do NOT delete from knowledge/rules.md.
**Step 7:** Add file header to each `.claude/rules/` file

**Verify:** `test -f .claude/rules/shell.md && test -f .claude/rules/workflow.md && test -f .claude/rules/subagent.md && test -f .claude/rules/debugging.md && grep -q 'Layer: Agent Rule' .claude/rules/shell.md`

### Task 4: Brainstorming Gate Hook

**Files:**
- Modify: `hooks/gate/pre-write.sh`
- Create: `tests/instruction-guard/test-brainstorm-gate.sh`

**Logic:** When writing a plan file (`docs/plans/*.md`, command=create), check that brainstorming confirmation exists. Use a flag file `.brainstorm-confirmed` that the @plan command flow sets after user confirms direction.

**Step 1: Write failing test**
```bash
#!/bin/bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
PASS=0; FAIL=0
run() {
  local desc="$1" input="$2" expect="$3"
  local rc=0; echo "$input" | bash hooks/gate/pre-write.sh >/dev/null 2>&1 || rc=$?
  if [ "$rc" -eq "$expect" ]; then echo "PASS: $desc"; PASS=$((PASS+1))
  else echo "FAIL: $desc (got $rc, want $expect)"; FAIL=$((FAIL+1)); fi
}
rm -f .brainstorm-confirmed
run "plan create blocked without brainstorm" '{"tool_name":"fs_write","tool_input":{"file_path":"docs/plans/2026-02-16-test.md","command":"create","new_str":"# Test"}}' 2
touch .brainstorm-confirmed
run "plan create allowed with brainstorm" '{"tool_name":"fs_write","tool_input":{"file_path":"docs/plans/2026-02-16-test.md","command":"create","new_str":"# Test"}}' 0
rm -f .brainstorm-confirmed
run "plan update always allowed" '{"tool_name":"fs_write","tool_input":{"file_path":"docs/plans/2026-02-16-test.md","command":"str_replace","new_str":"x"}}' 0
echo "Results: $PASS passed, $FAIL failed"; [ "$FAIL" -eq 0 ]
```

**Step 2:** Run test — verify fails
**Step 3:** Add `gate_brainstorm` function to pre-write.sh:
```bash
gate_brainstorm() {
  case "$FILE" in docs/plans/*.md) ;; *) return 0 ;; esac
  [ "$COMMAND" = "create" ] || [ "$TOOL_NAME" = "Write" ] || return 0
  [ -f ".skip-plan" ] && return 0
  [ -f ".brainstorm-confirmed" ] && return 0
  hook_block "🚫 BLOCKED: Creating plan without brainstorming confirmation.
Run brainstorming first and confirm direction with user."
}
```
**Step 4:** Run test — verify passes
**Step 5:** Update `commands/plan.md` — in Step 1 (Brainstorming), after "Do NOT proceed until the user confirms the direction", add: `touch .brainstorm-confirmed` when user confirms. In Step 7 (Hand Off), add: `rm -f .brainstorm-confirmed` after writing `.active` file (cleanup).

**Verify:** `bash tests/instruction-guard/test-brainstorm-gate.sh`

### Task 5: Split context-enrichment.sh

**Files:**
- Create: `hooks/feedback/correction-detect.sh`
- Create: `hooks/feedback/session-init.sh`
- Modify: `hooks/feedback/context-enrichment.sh`
- Create: `tests/context-enrichment/test-split.sh`

**Split:**

| Script | Responsibility |
|--------|---------------|
| `correction-detect.sh` | Correction detection + auto-capture trigger |
| `session-init.sh` | knowledge/rules.md injection + episode cleanup + promotion reminder + delegation reminder + health report (once per session via flag) |
| `context-enrichment.sh` | Research reminder + unfinished task resume (lightweight, every prompt) |

**Split mapping (what moves where):**

From `context-enrichment.sh` → `correction-detect.sh`:
- Correction detection regex blocks (5 if/elif blocks for CN/EN patterns)
- auto-capture.sh call and complex correction reminder
- Flag file creation (`agent-correction-*.flag`)

From `context-enrichment.sh` → `session-init.sh`:
- Episode cleanup (promoted episodes removal)
- `inject_rules` function (keyword section matching + injection from knowledge/rules.md)
- Promotion candidate reminder, delegation reminder, KB health report
- Flag file logic (`lessons-injected-*.flag`)

Remaining in `context-enrichment.sh`:
- Research skill reminder (CN/EN keyword detection)
- Unfinished task resume (`.completion-criteria.md` check)

**Step 1: Write failing test**
```bash
#!/bin/bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
PASS=0; FAIL=0
t() {
  local desc="$1"; shift
  if eval "$@" >/dev/null 2>&1; then echo "PASS: $desc"; PASS=$((PASS+1))
  else echo "FAIL: $desc"; FAIL=$((FAIL+1)); fi
}
t "correction-detect.sh exists" "test -x hooks/feedback/correction-detect.sh"
t "session-init.sh exists" "test -x hooks/feedback/session-init.sh"
t "correction detected" "echo '{\"prompt\":\"你错了\"}' | bash hooks/feedback/correction-detect.sh 2>&1 | grep -q CORRECTION"
t "research reminder works" "echo '{\"prompt\":\"调研一下\"}' | bash hooks/feedback/context-enrichment.sh 2>&1 | grep -q Research"
t "correction moved out" "! grep -q 'CORRECTION DETECTED' hooks/feedback/context-enrichment.sh"
t "rules injection moved out" "! grep -q 'inject_rules' hooks/feedback/context-enrichment.sh"
echo "Results: $PASS passed, $FAIL failed"; [ "$FAIL" -eq 0 ]
```

**Step 2:** Run test — verify fails
**Step 3:** Extract correction detection into `correction-detect.sh`, session-init into `session-init.sh`, slim `context-enrichment.sh`
**Step 4:** Run test — verify passes

**Verify:** `bash tests/context-enrichment/test-split.sh`

### Task 6: Update Config Generation & Documentation

**Files:**
- Modify: `scripts/generate-platform-configs.sh`
- Modify: `.kiro/rules/enforcement.md`
- Modify: `knowledge/INDEX.md`
- Modify: `skills/research/SKILL.md`

**Step 1:** Update generate-platform-configs.sh to register 3 userPromptSubmit hooks in this order: `correction-detect.sh` → `session-init.sh` → `context-enrichment.sh` (order matters: correction detection first, then session init with flag, then lightweight enrichment)
**Step 2:** Update enforcement.md Hook Registry with new hooks (instruction guard, brainstorm gate, split scripts)
**Step 3:** Update INDEX.md routing table to reflect new `.claude/rules/` files
**Step 4:** Add "调研后沉淀 checkpoint" step to research skill

**Verify:** `bash scripts/generate-platform-configs.sh && grep -q 'instruction' .kiro/rules/enforcement.md && grep -q 'shell.md' knowledge/INDEX.md && grep -q '沉淀' skills/research/SKILL.md`

### Task 7: @lint Health Check Command

**Files:**
- Create: `commands/lint.md`

**Content:** Define @lint command that checks:
- CLAUDE.md line count < 500
- `.claude/rules/` each file < 200 lines
- knowledge/rules.md vs `.claude/rules/` verbatim duplication (line-level diff)
- Each `.claude/rules/` file has Layer header
- CLAUDE.md and AGENTS.md in sync

**Verify:** `test -f commands/lint.md && grep -q '500' commands/lint.md`

## Review

### Round 1 (4 reviewers: Completeness, Testability, Compatibility, Clarity)
All REQUEST CHANGES. Fixed: added rollback strategy, Task 0 backup, strengthened verify commands, clarified AGENTS.md sync, migration criteria, split mapping, hook names.

### Round 2 (4 reviewers: Completeness, Testability, Technical Feasibility, Clarity)
2 APPROVE (Feasibility, Clarity), 2 REQUEST CHANGES. Fixed: hook execution order, atomic migration safety, diff timing, header check all files, config generation check.

### Round 3 (4 reviewers: Completeness, Testability, Security, Performance)
1 APPROVE (Performance), 3 REQUEST CHANGES. Fixed: @plan command modification details. 

Declined changes (by design):
- `.skip-instruction-guard` bypass: intentional emergency escape hatch for humans, consistent with existing `.skip-plan` pattern. Agent won't self-invoke because `touch` is not in pre-write hook scope.
- Flag file TOCTOU/concurrency: single-user CLI tool, no concurrent access.
- Hook input sanitization: already using jq for JSON parsing in all hooks.

## Checklist

- [x] Pre-migration backup tagged | `git tag | grep -q pre-governance-redesign`
- [x] CLAUDE.md write blocked by hook | `echo '{"tool_name":"fs_write","tool_input":{"file_path":"CLAUDE.md","command":"str_replace","new_str":"x"}}' | bash hooks/gate/pre-write.sh 2>&1; test $? -eq 2`
- [x] .claude/rules/ write blocked by hook | `echo '{"tool_name":"fs_write","tool_input":{"file_path":".claude/rules/security.md","command":"create","new_str":"x"}}' | bash hooks/gate/pre-write.sh 2>&1; test $? -eq 2`
- [x] episodes.md NOT blocked | `echo '{"tool_name":"fs_write","tool_input":{"file_path":"knowledge/episodes.md","command":"str_replace","new_str":"x"}}' | bash hooks/gate/pre-write.sh 2>&1; test $? -eq 0`
- [x] CLAUDE.md has Principles with 8 items | `sed -n '/^## Principles/,/^## /p' CLAUDE.md | grep -c '^- ' | grep -q 8`
- [x] CLAUDE.md has Authority Matrix | `grep -q '## Authority Matrix' CLAUDE.md`
- [x] CLAUDE.md has no Shell Safety section | `! grep -q '## Shell Safety' CLAUDE.md`
- [x] CLAUDE.md and AGENTS.md in sync | `bash scripts/generate-platform-configs.sh && diff CLAUDE.md AGENTS.md`
- [x] .claude/rules/shell.md exists with header | `for f in .claude/rules/shell.md .claude/rules/workflow.md .claude/rules/subagent.md .claude/rules/debugging.md .claude/rules/security.md; do grep -q 'Layer: Agent Rule' "$f" || exit 1; done`
- [x] .claude/rules/workflow.md exists | `test -f .claude/rules/workflow.md`
- [x] .claude/rules/subagent.md exists | `test -f .claude/rules/subagent.md`
- [x] .claude/rules/debugging.md exists | `test -f .claude/rules/debugging.md`
- [x] Plan create blocked without brainstorm flag | `rm -f .brainstorm-confirmed && echo '{"tool_name":"fs_write","tool_input":{"file_path":"docs/plans/2026-02-16-t.md","command":"create","new_str":"#T"}}' | bash hooks/gate/pre-write.sh 2>&1; test $? -eq 2`
- [x] Plan create allowed with brainstorm flag | `touch .brainstorm-confirmed && echo '{"tool_name":"fs_write","tool_input":{"file_path":"docs/plans/2026-02-16-t.md","command":"create","new_str":"#T"}}' | bash hooks/gate/pre-write.sh 2>&1; rc=$?; rm -f .brainstorm-confirmed; test $rc -eq 0`
- [x] correction-detect.sh exists and executable | `test -x hooks/feedback/correction-detect.sh`
- [x] session-init.sh exists and executable | `test -x hooks/feedback/session-init.sh`
- [x] context-enrichment.sh no longer has correction logic | `! grep -q 'CORRECTION DETECTED' hooks/feedback/context-enrichment.sh`
- [x] context-enrichment.sh no longer has inject_rules | `! grep -q 'inject_rules' hooks/feedback/context-enrichment.sh`
- [ ] enforcement.md updated | `grep -q 'instruction' .kiro/rules/enforcement.md`
- [ ] research skill has sedimentation step | `grep -q '沉淀' skills/research/SKILL.md`
- [ ] @lint command exists | `test -f commands/lint.md`
- [ ] Config generation succeeds | `bash scripts/generate-platform-configs.sh`
