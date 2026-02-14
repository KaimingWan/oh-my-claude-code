# Knowledge Base Overhaul — 3-Type Memory Architecture

**Goal:** 将混合知识库重构为语义/情景/程序三类记忆体系，提升知识质量、召回效率和自动入库能力。
**Architecture:** lessons-learned.md 拆分为 rules.md + episodes.md；INDEX.md 更新；context-enrichment 改造；self-reflect 增加去重和晋升逻辑。

## Decisions

| # | 决策 | 原因 | 状态 |
|---|------|------|------|
| 1 | 三分法：rules.md / episodes.md / reference/ | 行业共识（Reflexion, Generative Agents, SaMuLe），不同类型回答不同问题 | ✅ 采纳 |
| 2 | rules.md ≤2KB ≤30 条，每条 1-2 行 | agent 每次读，必须短平快可执行 | ✅ 采纳 |
| 3 | episodes 有 resolved 标记和 TTL | 已被 hook 拦截的不再注入 context，避免噪音 | ✅ 采纳 |
| 4 | 同类 episode ≥3 → 晋升为 rule | SaMuLe micro→meso→macro 模式，Focus Agent consolidation 验证 | ✅ 采纳 |
| 5 | context-enrichment 动态读 rules.md 而非硬编码 | 硬编码 4 条无法跟随知识演进 | ✅ 采纳 |

## Steps

### Task 1: 从 lessons-learned.md 提炼 rules.md

**Files:**
- Create: `knowledge/rules.md`
- Modify: `knowledge/lessons-learned.md` → rename to `knowledge/episodes.md`

**Step 1: 提炼规则**
从现有 lessons-learned.md 的 Mistakes/Wins/Rules Extracted 中提炼精炼规则，每条 1-2 行，格式：
```markdown
# Agent Rules (Semantic Memory)
> Distilled from repeated episodes. Each rule is a proven constraint.

1. JSON = jq，无条件无例外。禁止 sed/awk/grep 修改 JSON。[hook: block-sed-json]
2. macOS 用 stat -f，禁止 stat -c（GNU-only）。
3. grep -c 无匹配时 exit 1 但仍输出 0，不要和 || echo 0 组合。
...
```

带 `[hook: xxx]` 标记的表示已有 hook 强制执行。

**Step 2: 重构 episodes.md**
将 lessons-learned.md 重命名为 episodes.md，格式改造：
- 合并重复条目（10 条 sed/JSON → 1 条，标注 `×10, resolved`）
- 合并 3 条 stat -c → 1 条，标注 `×3, resolved`
- 每条增加 status 列：`active` / `resolved` / `promoted`
- `resolved` = 已有 hook 拦截；`promoted` = 已提炼为 rule

**Step 3: 验证**
```bash
wc -c knowledge/rules.md  # ≤2048
grep -c '^[0-9]' knowledge/rules.md  # ≤30
test ! -f knowledge/lessons-learned.md && echo "RENAMED"
```

### Task 2: 更新 INDEX.md 和引用

**Files:**
- Modify: `knowledge/INDEX.md`
- Modify: `AGENTS.md` / `CLAUDE.md` — 更新 lessons-learned 引用
- Modify: `hooks/feedback/context-enrichment.sh` — 动态读 rules.md

**Step 1: 更新 INDEX.md**
路由表改为：
```
| Agent rules & constraints | knowledge/rules.md | "JSON 用什么工具？" |
| Past incidents & events | knowledge/episodes.md | "这个错误以前犯过吗？" |
| Reference materials | knowledge/reference/ | "Mermaid 语法？" |
```

**Step 2: 更新 AGENTS.md / CLAUDE.md**
将 `lessons-learned.md` 引用改为 `rules.md`（agent 日常读规则，不读事件日志）。

**Step 3: context-enrichment.sh 改造**
将硬编码的 4 条 HIGH-FREQ LESSONS 替换为动态读取 rules.md 前 10 条：
```bash
# 替换硬编码 lessons 块
if [ ! -f "$LESSONS_FLAG" ]; then
  if [ -f "knowledge/rules.md" ]; then
    echo "📚 AGENT RULES (from knowledge/rules.md):"
    grep '^[0-9]' "knowledge/rules.md" | head -10
  fi
  touch "$LESSONS_FLAG"
fi
```

**Step 4: 验证**
```bash
grep -r 'lessons-learned' AGENTS.md CLAUDE.md hooks/ knowledge/INDEX.md 2>/dev/null || echo "CLEAN"
```

### Task 3: self-reflect 增加去重和晋升逻辑

**Files:**
- Modify: `skills/self-reflect/SKILL.md` — 增加去重检查和晋升触发指引

**Step 1: 在 "On Detection" 段落增加去重和晋升步骤**
```
## On Detection
1. Check: does a similar rule already exist in knowledge/rules.md?
   - If yes → skip writing, just reference the existing rule
2. Check: does a similar episode exist in knowledge/episodes.md?
   - If yes (≥2 similar) → promote to rule in rules.md, mark episodes as `promoted`
3. If new → write to episodes.md with status `active`
4. Confirm: 📝 Learning captured: '[preview]' → [target file]
```

**Step 2: 更新 Sync Targets 表**
```
| Rule Type | Target File |
|-----------|-------------|
| Proven constraint (≥3 occurrences) | knowledge/rules.md |
| First/second occurrence | knowledge/episodes.md |
| Code-enforceable | .kiro/rules/enforcement.md |
| High-frequency | CLAUDE.md / AGENTS.md |
```

**Step 3: 验证**
```bash
grep -c 'rules.md\|episodes.md\|dedup\|promot' skills/self-reflect/SKILL.md
# 应该 ≥4
```

### Task 4: 全局引用清理

**Files:**
- Grep 全项目，修复所有 `lessons-learned.md` 残留引用

**Step 1: 查找并修复**
```bash
grep -r 'lessons-learned' . --include='*.md' --include='*.sh' | grep -v '.git' | grep -v 'episodes.md'
```
将所有引用更新为 `rules.md`（日常查询）或 `episodes.md`（事件查询）。

**Step 2: 验证**
```bash
grep -r 'lessons-learned' . --include='*.md' --include='*.sh' | grep -v '.git' | grep -v node_modules || echo "CLEAN"
```

## Review

### Strengths
- **Clear architectural vision**: 3-type memory (semantic/episodic/procedural) aligns with cognitive science and proven agent frameworks
- **Concrete size constraints**: rules.md ≤2KB ≤30 items prevents context bloat
- **Deduplication strategy**: Merging 15 duplicate sed/JSON entries addresses real waste
- **Dynamic context injection**: Replacing hardcoded lessons with rules.md enables evolution
- **Status tracking**: resolved/promoted flags prevent noise injection
- **Comprehensive checklist**: 12 concrete acceptance criteria

### Weaknesses
- **CRITICAL: Missing validation steps**: No verification that extracted rules actually work or are enforceable
- **Risk: Rule quality control**: No criteria for what makes a "good" 1-2 line rule vs verbose explanation
- **Missing: Rollback plan**: If new architecture breaks existing workflows, no recovery path
- **Incomplete: TTL mechanism**: Episodes mention TTL but no implementation details or cleanup process
- **Risk: Context-enrichment timing**: Dynamic reading adds I/O overhead to every prompt submission

### Missing Critical Elements
- **Validation testing**: Should test that rules.md injection actually improves agent behavior
- **Rule promotion criteria**: "≥3 occurrences" is vague - need specific similarity matching logic
- **Backup strategy**: Should backup lessons-learned.md before destructive rename
- **Performance impact**: No measurement of context-enrichment.sh latency increase
- **Edge case: Empty files**: What if rules.md doesn't exist or is empty?
- **Migration verification**: Should verify all existing lessons are preserved in new structure

### Missing Steps
- **Step 0**: Backup current lessons-learned.md
- **Validation step**: Test rules.md injection in isolated environment
- **Performance benchmark**: Measure context-enrichment.sh before/after
- **Similarity detection**: Define algorithm for detecting "similar episodes"
- **Cleanup verification**: Ensure no broken references in documentation

### Verdict: **REQUEST CHANGES**

**Blocking issues:**
1. **CRITICAL**: No validation that extracted rules improve agent performance
2. **CRITICAL**: Missing backup strategy for 12KB lessons-learned.md
3. **CRITICAL**: Undefined similarity detection for episode promotion
4. **WARNING**: No rollback plan if architecture fails
5. **WARNING**: Performance impact on context-enrichment.sh not assessed

**Required additions:**
- Add backup step before any destructive operations
- Define concrete similarity matching algorithm for episodes
- Add validation testing of rules.md effectiveness
- Include performance benchmarking
- Add rollback procedures

## Checklist

- [ ] knowledge/rules.md 已创建，≤2KB，≤30 条
- [ ] 每条 rule 格式为 1-2 行精炼可执行规则
- [ ] 已有 hook 的 rule 标注 [hook: xxx]
- [ ] knowledge/episodes.md 已创建（从 lessons-learned.md 重构）
- [ ] 重复 episode 已合并（sed/JSON ×10→1, stat -c ×3→1）
- [ ] 每条 episode 有 status 列（active/resolved/promoted）
- [ ] knowledge/INDEX.md 路由表已更新为三类结构
- [ ] AGENTS.md 不再引用 lessons-learned.md
- [ ] context-enrichment.sh 动态读 rules.md 而非硬编码
- [ ] self-reflect SKILL.md 包含去重检查逻辑
- [ ] self-reflect SKILL.md 包含晋升触发逻辑（≥3 同类→rule）
- [ ] grep -r 'lessons-learned' 全项目无残留引用
