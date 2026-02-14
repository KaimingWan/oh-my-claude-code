# Subagent Selective Delegation Plan

**Goal:** Establish clear delegation rules + fix subagent security gaps + optimize main agent context usage. Zero capability degradation.
**Architecture:** Rules in AGENTS.md (always loaded) + context-enrichment hint for complex tasks + subagent hook hardening + planning skill update.

## Key Decisions

1. **Selective, not aggressive** — only delegate when subagent tools (read/write/shell) can match main agent quality
2. **Three principles**: no capability degradation, result self-contained, task independent
3. **No new skill** — rules are simple enough for AGENTS.md + planning skill update
4. **Hook-driven safety** — all subagents get full security hooks (block-dangerous + block-sed-json + block-secrets)
5. **Manual decision** — main agent decides delegation based on rules in AGENTS.md, no automatic detection (too complex, too fragile)
6. **Mixed tasks stay on main agent** — if any part of a task needs code/grep/web tools, the whole task stays on main agent (splitting introduces context loss)

## Delegation Boundary

### Always delegate (when applicable)
- Plan review → reviewer subagent
- Independent task execution (>3 tasks) → implementer subagent per task (Strategy C)
- Parallel independent file modifications → multiple implementer subagents
- Batch verification (run tests, check file states) → any subagent

### Never delegate
- Tasks needing `code` tool (LSP, symbol search, goto_definition)
- Tasks needing `grep` tool (structured regex search)
- Tasks needing `web_search` / `web_fetch`
- Tasks needing AWS CLI
- File reads where main agent needs raw content for subsequent decisions
- Multi-step operations with cross-step context dependency
- **Mixed tasks** — if any subtask needs a main-agent-only tool, keep the whole task on main agent

## Tasks

### Task 1: Harden subagent security hooks

**Files:** Modify `.kiro/agents/implementer.json`, `.kiro/agents/reviewer.json`, `.kiro/agents/debugger.json`, `.kiro/agents/researcher.json`

Add missing security hooks to all subagents. Current gap:
- implementer: has block-dangerous, missing block-sed-json + block-secrets
- reviewer: has block-dangerous, missing block-sed-json + block-secrets
- debugger: has block-dangerous, missing block-sed-json + block-secrets
- researcher: no preToolUse hooks at all

Target: all 4 subagents have identical preToolUse security hooks:
```json
"preToolUse": [
  {"matcher": "execute_bash", "command": "hooks/security/block-dangerous.sh"},
  {"matcher": "execute_bash", "command": "hooks/security/block-secrets.sh"},
  {"matcher": "execute_bash", "command": "hooks/security/block-sed-json.sh"}
]
```

Verify: `jq '.hooks.preToolUse' .kiro/agents/*.json` — all 4 should show 3 entries.

### Task 2: Update AGENTS.md with delegation rules

**Files:** Modify `AGENTS.md`

Add a `## Subagent Delegation` section after `Self-Learning`:

```markdown
## Subagent Delegation
- 三原则：能力不降级 / 结果自包含 / 任务独立
- 决策方式：主 agent 自行判断，不自动检测
- 需要 code tool、grep tool、web_search、AWS CLI 的任务 → 主 agent 自己做
- 需要原始数据做后续决策的读取 → 主 agent 自己做
- 混合任务（部分需要主 agent 工具）→ 整个任务留在主 agent，不拆分
- Plan review → reviewer subagent
- 独立 task 执行（>3 tasks）→ implementer subagent per task
- 批量验证 → subagent
```

Verify: `grep -c 'Subagent Delegation' AGENTS.md` = 1

### Task 3: Update planning skill Strategy C

**Files:** Modify `skills/planning/SKILL.md`

Add capability constraints note after Strategy C section:

```markdown
**Subagent capability limits (do NOT delegate tasks that need these):**
- `code` tool (LSP analysis, symbol search, goto_definition)
- `grep` tool (structured regex search with context)
- `web_search` / `web_fetch` (internet access)
- `use_aws` (AWS CLI)
- Cross-step context (subagents are stateless between invocations)
```

Verify: `grep -c 'capability limits' skills/planning/SKILL.md` = 1

### Task 4: Add context-enrichment delegation hint

**Files:** Modify `hooks/feedback/context-enrichment.sh`

After the rules injection block (inside the `if [ ! -f "$LESSONS_FLAG" ]` block), add:

```bash
echo "⚡ Delegation: >3 independent tasks → use subagent per task. Never delegate code/grep/web_search tasks."
```

One line, injected once per session alongside rules. No bloat.

Verify: `grep -c 'Delegation:' hooks/feedback/context-enrichment.sh` = 1

### Task 5: Fix generate-platform-configs.sh subagent security hooks

**Files:** Modify `scripts/generate-platform-configs.sh`

Current state: reviewer/implementer/debugger only have `block-dangerous` in preToolUse. Researcher has NO preToolUse at all.

Fix all 4 subagent sections to include 3 security hooks:
- Line ~124 (reviewer): expand single preToolUse to 3 entries
- Line ~151 (implementer): expand single preToolUse to 3 entries
- Line ~180 (debugger): expand single preToolUse to 3 entries
- Line ~204 (researcher): add preToolUse with 3 entries

Verify: `bash scripts/generate-platform-configs.sh && jq '.hooks.preToolUse | length' .kiro/agents/{implementer,reviewer,debugger,researcher}.json` — all return 3

### Task 6: Record in episodes.md

**Files:** Modify `knowledge/episodes.md`

Append: `2026-02-15 | active | subagent,delegation,context | subagent选择性委派: 能力不降级/结果自包含/任务独立, 需要code/grep/web工具的不委派`

Verify: `grep -c 'subagent' knowledge/episodes.md` ≥ 1

## Review (Round 2)

### Strengths
- **Round 1 issues properly addressed**: Task 5 now has exact line references (~124, ~151, ~180, ~204), delegation decision logic added as decisions 5+6, mixed task handling explicitly covered in "Never delegate" list
- **Clear delegation boundary**: Well-defined "Always delegate" vs "Never delegate" with specific tool constraints (code/grep/web_search/AWS CLI)
- **Security hardening**: All 4 subagents get identical 3-hook security (block-dangerous + block-sed-json + block-secrets)
- **Minimal implementation**: No new skill, uses existing AGENTS.md + planning skill update + single context-enrichment hint
- **Verification built-in**: Each task has concrete verification commands

### Remaining Issues
- **Task 5 line numbers may drift**: Script line references (~124, ~151, ~180, ~204) could become inaccurate if script changes. Consider using section markers or grep patterns instead
- **Context-enrichment timing**: The delegation hint injection happens "once per session" but timing unclear - should specify when in session (first complex task? planning skill activation?)
- **Rollback strategy incomplete**: While "git revert suffices" is mentioned, no specific rollback verification steps provided

### Verdict
**APPROVE** - All Round 1 issues resolved, plan is implementable with clear verification. Minor line number fragility acceptable given concrete verification commands will catch any drift.

### Round 1 Feedback (addressed)
- ~~Task 5 broken~~ → Fixed: now specifies exact lines and all 4 subagent sections
- ~~Missing delegation decision logic~~ → Added: decision 5 (manual, no auto-detect) + AGENTS.md text updated
- ~~Mixed task handling~~ → Added: decision 6 (keep whole task on main agent) + "Never delegate" list updated
- ~~Rollback~~ → Not needed: changes are config-only, git revert suffices

## Checklist
- [ ] All 4 subagents have 3 security hooks (block-dangerous + block-sed-json + block-secrets)
- [ ] AGENTS.md has `## Subagent Delegation` section with 3 principles
- [ ] planning SKILL.md has capability limits note under Strategy C
- [ ] context-enrichment.sh has one-line delegation hint
- [ ] generate-platform-configs.sh includes security hooks for subagents
- [ ] episodes.md has delegation principle entry
- [ ] No capability degradation: code/grep/web_search tasks stay on main agent
- [ ] `jq '.hooks.preToolUse // [] | length' .kiro/agents/{implementer,reviewer,debugger,researcher}.json` all return 3
