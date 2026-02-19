# Context & Skill Optimization Plan

**Goal:** Reduce context overhead by ~40% (skill resources) and ~500-800 bytes/message (hook output), while maintaining full CC + Kiro capability parity. Eliminate skill redundancy, streamline hook verbosity, and trigger episodes distillation.

**Non-Goals:**
- Rewriting hook logic or changing enforcement behavior
- Modifying planning/reviewing skill content (beyond brainstorming merge)
- Changing the knowledge retrieval architecture (INDEX.md stays)
- Restructuring the hook system itself

**Architecture:** Three-layer optimization: (1) resource loading — reduce from 9 skills to 2 preloaded, (2) hook output — strip internal diagnostics, keep only actionable messages, (3) episodes cleanup — trigger distillation to unblock the pipeline. All changes flow through generate_configs.py as single source of truth.

**Tech Stack:** Bash (hooks), Python (generate_configs.py), Markdown (skills, plans, AGENTS.md)

## Tasks

### Task 1: Skill Resource Pruning in generate_configs.py

**Files:**
- Modify: `scripts/generate_configs.py`

Change pilot/default resources from `skill://skills/**/SKILL.md` (all 9 skills) to explicit `skill://skills/planning/SKILL.md` + `skill://skills/reviewing/SKILL.md` (2 skills). Remove `AGENTS.md` from reviewer and researcher subagent resources (they don't need full framework principles).

**Verify:**
```bash
python3 scripts/generate_configs.py && jq '.resources' .kiro/agents/pilot.json | grep -c 'skill://' | grep -q '^2$' && echo PASS || echo FAIL
```

### Task 2: Merge Brainstorming into Planning Phase 0

**Files:**
- Modify: `skills/planning/SKILL.md`
- Modify: `commands/plan.md`
- Move: `skills/brainstorming/` → `.trash/brainstorming/`

Add brainstorming's unique value (design presentation in 200-300 word sections, write to docs/designs/) to planning Phase 0 as optional step. Update commands/plan.md Step 1 to reference planning Phase 0 instead of brainstorming.

**Verify:**
```bash
test ! -d skills/brainstorming && grep -q 'Design presentation' skills/planning/SKILL.md && ! grep -q 'brainstorming' commands/plan.md && echo PASS || echo FAIL
```

### Task 3: Update AGENTS.md Skill Routing Table

**Files:**
- Modify: `AGENTS.md`
- Modify: `CLAUDE.md`

Update Skill Routing table to reflect new loading strategy (预加载 vs 按需读取). Sync CLAUDE.md = AGENTS.md.

**Verify:**
```bash
grep -q '加载方式' AGENTS.md && diff AGENTS.md CLAUDE.md > /dev/null && echo PASS || echo FAIL
```

### Task 4: Hook Output Streamlining — context-enrichment.sh

**Files:**
- Modify: `hooks/feedback/context-enrichment.sh`
- Modify: `tests/knowledge/test-enrichment-v2.sh`

Layer 3 (episode hints): change from outputting each episode's 40-char summary (N lines) to single count line `📌 N related episodes found`. Layer 4 (archive hint): remove entirely. Update test assertions (including E5 archive assertion removal in test-enrichment-v2.sh).

**Verify:**
```bash
bash tests/knowledge/test-enrichment-v2.sh
```

### Task 5: Hook Output Streamlining — Other Hooks

**Files:**
- Modify: `hooks/feedback/session-init.sh`
- Modify: `hooks/feedback/auto-capture.sh`
- Modify: `hooks/feedback/verify-completion.sh`
- Modify: `hooks/feedback/post-write.sh`
- Modify: `hooks/_lib/distill.sh`
- Modify: `hooks/gate/enforce-ralph-loop.sh`
- Modify: `tests/knowledge/test-distill.sh`
- Modify: `tests/hooks/test-auto-capture.sh`

session-init: remove 🧹 cleanup and 📊 health report output, keep ⬆️ promotion reminder. auto-capture: remove "Already in rules" and "Similar episode exists" dedup diagnostics. verify-completion: remove ═══ decoration lines, compact INCOMPLETE to 1 line. post-write: remove "File updated" reminder. distill.sh: silence "Distilled" and "Archived" output. enforce-ralph-loop: compact block_msg function to output 1 echo line instead of 4. Update affected test assertions (including test-enrichment-v2.sh E5 archive assertion, test-severity-tracking.sh capacity assertion).

**Verify:**
```bash
bash tests/knowledge/test-distill.sh && bash tests/hooks/test-auto-capture.sh && bash tests/knowledge/test-integration.sh && bash tests/knowledge/test-severity-tracking.sh && echo PASS || echo FAIL
```

### Task 6: Trigger Episodes Distillation

**Files:**
- Modify: `knowledge/episodes.md`
- Modify: `knowledge/rules.md`

Run distill pipeline to promote high-frequency keywords (≥2 occurrences) to rules.md, archive promoted episodes, enforce section cap. Target: active episodes ≤ 30.

**Verify:**
```bash
test $(grep -c '| active |' knowledge/episodes.md) -le 30 && grep -c '^## \[' knowledge/rules.md | grep -qv '^0$' && echo PASS || echo FAIL
```

### Task 7: Regenerate Configs & Final Validation

**Files:**
- Modify: `.kiro/agents/default.json` (generated)
- Modify: `.kiro/agents/pilot.json` (generated)
- Modify: `.kiro/agents/reviewer.json` (generated)
- Modify: `.kiro/agents/researcher.json` (generated)
- Modify: `.claude/settings.json` (generated)
- Modify: `.claude/agents/reviewer.md` (generated)
- Modify: `.claude/agents/executor.md` (generated)
- Modify: `.claude/agents/researcher.md` (generated)

Regenerate all configs from generate_configs.py, validate, run full test suite.

**Verify:**
```bash
python3 scripts/generate_configs.py --validate && bash tests/knowledge/test-enrichment-v2.sh && bash tests/knowledge/test-distill.sh && echo PASS || echo FAIL
```

## Review
<!-- Reviewer writes here -->

## Checklist

- [ ] generate_configs.py resources 改为只加载 planning + reviewing | `python3 scripts/generate_configs.py && jq '.resources' .kiro/agents/pilot.json | grep -c 'skill://' | grep -q '^2$'`
- [ ] subagent 不再加载 AGENTS.md | `python3 scripts/generate_configs.py && ! jq '.resources[]' .kiro/agents/reviewer.json 2>/dev/null | grep -q 'AGENTS.md'`
- [ ] brainstorming 合并入 planning Phase 0 并移除 | `test ! -d skills/brainstorming && grep -q 'Design presentation' skills/planning/SKILL.md`
- [ ] commands/plan.md 不再引用 brainstorming | `! grep -q 'brainstorming' commands/plan.md`
- [ ] AGENTS.md Skill Routing 表更新 | `grep -q '加载方式' AGENTS.md`
- [ ] CLAUDE.md 与 AGENTS.md 同步 | `diff AGENTS.md CLAUDE.md`
- [ ] context-enrichment episode hints 精简为计数 | `echo '{"prompt":"test subagent code"}' | bash hooks/feedback/context-enrichment.sh 2>/dev/null | grep -q '📌' && ! echo '{"prompt":"test subagent code"}' | bash hooks/feedback/context-enrichment.sh 2>/dev/null | grep -q 'Episode:'`
- [ ] archive hint 已移除 | `! echo '{"prompt":"test"}' | bash hooks/feedback/context-enrichment.sh 2>/dev/null | grep -q '📦'`
- [ ] session-init 移除 cleanup/health 输出 | `! grep -q '🧹\|📊' hooks/feedback/session-init.sh`
- [ ] auto-capture 移除 dedup 诊断输出 | `! grep -q 'Already in rules\|Similar episode exists' hooks/feedback/auto-capture.sh`
- [ ] verify-completion 移除装饰线 | `! grep -q '═══' hooks/feedback/verify-completion.sh`
- [ ] post-write 移除低价值提醒 | `! grep -q 'File updated' hooks/feedback/post-write.sh`
- [ ] distill.sh 静默执行 | `! grep -qE 'echo.*Distilled|echo.*Archived' hooks/_lib/distill.sh`
- [ ] enforce-ralph-loop block_msg 函数精简为1行输出 | `awk '/^block_msg/,/^}/' hooks/gate/enforce-ralph-loop.sh | grep -c 'echo' | grep -q '^1$'`
- [ ] episodes 蒸馏完成（active ≤ 30） | `test $(grep -c '| active |' knowledge/episodes.md) -le 30`
- [ ] rules.md 有蒸馏产出 | `grep -c '^## \[' knowledge/rules.md | grep -qv '^0$'`
- [ ] 测试通过: enrichment | `bash tests/knowledge/test-enrichment-v2.sh`
- [ ] 测试通过: distill | `bash tests/knowledge/test-distill.sh`
- [ ] 测试通过: integration | `bash tests/knowledge/test-integration.sh`
- [ ] 测试通过: auto-capture | `bash tests/hooks/test-auto-capture.sh`
- [ ] 测试通过: severity-tracking | `bash tests/knowledge/test-severity-tracking.sh`
- [ ] 生成配置验证通过 | `python3 scripts/generate_configs.py --validate`

## Errors

| Error | Task | Attempt | Resolution |
|-------|------|---------|------------|
