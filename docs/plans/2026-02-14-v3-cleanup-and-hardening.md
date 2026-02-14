# v3 Cleanup & Hardening

**Goal:** 清理 v2→v3 迁移残留，增强纠正检测覆盖率，提升 verify-completion 可见性，消除 self-reflect 设计矛盾。
**Architecture:** 纯文件删除/修改，不新增模块。涉及 skills/、hooks/、knowledge/ 三个目录。
**Scope:** 4 项变更，无新依赖。

## Decisions

| # | 决策 | 原因 | 状态 |
|---|------|------|------|
| 1 | 删除 PRODUCT.md 机制而非填充 | 框架本身不需要产品地图，空壳浪费 context | ✅ 采纳 |
| 2 | verify-completion 输出加强 + 前移到 require-workflow gate | Stop hook 在 Kiro 不能阻断，前移到 PreToolUse 才能硬拦截 | ✅ 采纳 |
| 3 | 纠正检测只扩充正则，不引入 LLM | keep simple，确定性优先，不够用以后再增强 | ✅ 采纳 |
| 4 | 删除 self-reflect queue 机制 | v2 遗留，与 v3 "immediate write" 原则矛盾 | ✅ 采纳 |
| 5 | 度量/可观测性不做 | 优先级不高，以后再说 | ❌ 推迟 |

## Steps

### Task 1: 删除 PRODUCT.md 机制

**Files:**
- Delete: `knowledge/product/PRODUCT.md`
- Delete: `knowledge/product/INDEX.md`
- Delete: `knowledge/product/` (目录)
- Modify: `skills/brainstorming/SKILL.md` — 移除 "read PRODUCT.md" 引用
- Modify: `skills/planning/SKILL.md` — 移除 "read PRODUCT.md" 引用和 Phase 3 更新 PRODUCT.md
- Modify: `knowledge/INDEX.md` — 移除 product 相关路由条目

**Step 1: 删除文件和目录**
```bash
rm -rf knowledge/product/
```

**Step 2: 清理 brainstorming skill**
移除 `If knowledge/product/PRODUCT.md exists and is non-empty, read it first` 相关行。

**Step 3: 清理 planning skill**
移除 `Before writing: Read knowledge/product/PRODUCT.md` 和 Phase 3 中 `Update knowledge/product/PRODUCT.md if features changed`。

**Step 4: 清理 knowledge/INDEX.md**
移除 `Product features & constraints` 路由行和 Quick Links 中的 Product Map 链接。

**Step 5: 验证（全面搜索）**
```bash
grep -r "PRODUCT.md\|product/INDEX\|knowledge/product" skills/ knowledge/ hooks/ commands/ CLAUDE.md AGENTS.md .claude/rules/ 2>/dev/null | grep -v '.git' || echo "CLEAN"
```

### Task 2: verify-completion 增强 + 前移检查

**Files:**
- Modify: `hooks/feedback/verify-completion.sh` — 输出格式加强
- Modify: `hooks/gate/require-workflow.sh` — 增加 checklist 未完成检查

**Step 1: 加强 verify-completion.sh 输出格式**
将 `⚠️ INCOMPLETE` 改为更醒目的格式：
```
🚫 ═══════════════════════════════════════
🚫 INCOMPLETE: N/M checklist items remaining
🚫 ═══════════════════════════════════════
```

**Step 2: require-workflow.sh 增加 checklist 前移检查**
在 verdict 检查通过后（exit 0 之前），增加 advisory 检查：

```bash
# 8. Advisory: remind about unchecked items
UNCHECKED=$(grep -c '^\- \[ \]' "$PLAN_FILE" 2>/dev/null || true)
CHECKED=$(grep -c '^\- \[x\]' "$PLAN_FILE" 2>/dev/null || true)
if [ "${UNCHECKED:-0}" -gt 0 ]; then
  echo "📋 Progress: $CHECKED/$((CHECKED + UNCHECKED)) checklist items done in $PLAN_FILE" >&2
fi
```

不阻断（exit 0），因为正在写代码说明正在完成 checklist 项。但每次写文件都提醒进度。

**Step 3: 验证**
```bash
bash hooks/feedback/verify-completion.sh < /dev/null; echo "exit: $?"
```

### Task 3: 扩充纠正检测正则

**Files:**
- Modify: `hooks/feedback/context-enrichment.sh` — 扩充正则模式

**Step 1: 增加隐式否定模式**
在现有 3 个 `elif` 分支后增加第 4 个分支，覆盖：
- 中文隐式否定：`不是我(想要|要的|期望|需要)的`、`换个(思路|方式|方法|方案)`、`不是这样`、`这样不行`、`重新来`、`不是我要的`、`不够好`、`差太远`、`完全不对`、`跑偏了`、`方向错了`
- 英文隐式否定：`not what I (want|need|expect|asked)`、`try (again|different|another)`、`wrong approach`、`start over`、`that's not it`、`off track`、`missed the point`

**Step 2: 验证（含误触发测试）**
```bash
# 应触发
echo '{"prompt":"这不是我想要的效果"}' | bash hooks/feedback/context-enrichment.sh
echo '{"prompt":"换个思路吧"}' | bash hooks/feedback/context-enrichment.sh
echo '{"prompt":"not what I wanted"}' | bash hooks/feedback/context-enrichment.sh
echo '{"prompt":"try a different approach"}' | bash hooks/feedback/context-enrichment.sh
echo '{"prompt":"完全不对"}' | bash hooks/feedback/context-enrichment.sh
# 不应触发
echo '{"prompt":"今天天气不错"}' | bash hooks/feedback/context-enrichment.sh
echo '{"prompt":"帮我写个函数"}' | bash hooks/feedback/context-enrichment.sh
echo '{"prompt":"这个方案不错，继续"}' | bash hooks/feedback/context-enrichment.sh
```

### Task 4: 删除 self-reflect queue 机制

**Files:**
- Delete: `skills/self-reflect/reflect_utils.py`
- Delete: `skills/self-reflect/commands/reflect.md`
- Delete: `skills/self-reflect/commands/view-queue.md`
- Delete: `skills/self-reflect/commands/skip-reflect.md`
- Delete: `skills/self-reflect/commands/` (目录)
- Modify: `skills/self-reflect/SKILL.md` — 移除 Commands 表格中 queue 相关命令

**Step 1: 删除文件**
```bash
rm -f skills/self-reflect/reflect_utils.py
rm -rf skills/self-reflect/commands/
```

**Step 2: 清理 SKILL.md**
移除 Commands 段落中的 `/reflect`、`/view-queue`、`/skip-reflect` 行，以及 "Review & Sync" 示例。

**Step 3: 验证**
```bash
ls skills/self-reflect/
# 应该只剩 SKILL.md
grep -c 'queue\|/reflect\|/view-queue\|/skip-reflect' skills/self-reflect/SKILL.md
# 应该输出 0
```

## Review

### Round 1 — REQUEST CHANGES (addressed)

**Strengths:**
- Clear scope with 4 focused changes, no feature creep
- Concrete checklist with 13 testable acceptance criteria
- Each task has verification commands for immediate feedback
- Addresses real technical debt (empty PRODUCT.md, v2 queue mechanism)
- Logical progression: delete unused → enhance existing → expand detection → remove contradictory

**Weaknesses:**
- ~~Task 2 Step 2 is vague: "输出警告（不阻断）" - what's the exact warning format?~~ → Fixed: added exact bash code
- No rollback plan if modified files → Not needed: git tracks all changes
- ~~Task 3 regex patterns could create false positives~~ → Fixed: added 3 negative test cases + 3 checklist items
- ~~Missing impact analysis on existing workflows that might depend on PRODUCT.md~~ → Fixed: expanded grep scope

**Missing:**
- ~~Pre-execution backup strategy for modified files~~ → git is the backup
- ~~Testing plan for edge cases in context-enrichment.sh regex~~ → Fixed: 5 positive + 3 negative test cases
- ~~Documentation updates~~ → knowledge/INDEX.md update already in Task 1
- ~~Consideration of concurrent plan execution conflicts~~ → N/A, single-user framework

**Required fixes (all addressed):**
1. ~~Specify exact warning format and logic for Task 2 Step 2~~ → Done
2. ~~Add backup step before file modifications~~ → git suffices
3. ~~Add comprehensive grep check for all references before deletion~~ → Done
4. ~~Define regex testing strategy to prevent false positives~~ → Done

### Round 2 — APPROVE

**Round 1 Fixes Assessment:**
✅ All 4 required fixes properly addressed:
1. Task 2 Step 2 now has exact bash code for checklist progress display
2. Backup strategy: git is the backup (rejected as unnecessary)  
3. Grep check expanded to cover hooks/commands/rules directories
4. Added 5 positive + 3 negative regex test cases and 3 additional checklist items for false positives

**Implementation Detail:**
✅ Sufficient - each task has concrete bash commands, file paths, and verification steps
✅ Task 2 Step 2 bash code is production-ready
✅ Task 3 regex patterns are comprehensive with proper testing
✅ All 16 checklist items are testable and specific

**Remaining Gaps/Risks:**
⚠️ Minor: Task 3 regex could still have edge cases, but testing strategy mitigates this
⚠️ Minor: No rollback procedure beyond git, but changes are low-risk file operations
✅ No blocking issues identified

**Verdict: APPROVE**
- All Round 1 feedback incorporated
- Implementation detail is sufficient for execution
- Risk level acceptable for cleanup tasks
- Clear verification strategy for each change

## Checklist

- [x] knowledge/product/ 目录已删除
- [x] brainstorming skill 不再引用 PRODUCT.md
- [x] planning skill 不再引用 PRODUCT.md
- [x] knowledge/INDEX.md 不再引用 product
- [x] grep -r "PRODUCT.md" 在 skills/knowledge/hooks/commands/rules 下无结果
- [x] verify-completion.sh 输出格式更醒目
- [x] require-workflow.sh 包含 checklist 未完成检查
- [x] context-enrichment.sh 能匹配 "这不是我想要的效果"
- [x] context-enrichment.sh 能匹配 "换个思路"
- [x] context-enrichment.sh 能匹配 "not what I wanted"
- [x] context-enrichment.sh 不误触发 "今天天气不错"
- [x] context-enrichment.sh 不误触发 "帮我写个函数"
- [x] context-enrichment.sh 不误触发 "这个方案不错，继续"
- [x] reflect_utils.py 已删除
- [x] self-reflect/commands/ 目录已删除
- [x] self-reflect SKILL.md 不再包含 queue/reflect/view-queue 相关内容
