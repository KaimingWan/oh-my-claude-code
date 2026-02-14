# 持久化记忆融入方案（参考 planning-with-files）

**Goal:** 将 planning-with-files 的"文件当持久记忆"最佳实践融入框架，让 ralph-loop 每轮迭代通过磁盘文件传递上下文，并用 hook 辅助强化写文件纪律。

**Architecture:** ralph-loop prompt 加入 progress.md/findings.md 读写规则 + PreToolUse hook 注入 plan 上下文 + PostToolUse hook 提醒写文件。

## Tasks

### Task 1: 修改 `scripts/ralph-loop.sh` prompt

**Files:**
- Modify: `scripts/ralph-loop.sh`

在 prompt 中加入：
- 启动时读 `progress.md`（前几轮的日志和发现）和 `findings.md`（调研结果）
- 每完成一个 task 后 append 到 `progress.md`：做了什么、改了哪些文件、踩的坑
- 调研发现写入 `findings.md`：技术决策、代码 pattern、资源链接
- 两个文件放在 plan 同目录下

**progress.md 格式：**
```markdown
## Iteration N — [timestamp]
- **Task:** [checklist item description]
- **Files changed:** file1, file2
- **Learnings:** [discoveries, gotchas]
- **Status:** done / skipped
```

**findings.md 格式：**
```markdown
## [Topic]
- **Decision:** [what was decided]
- **Rationale:** [why]
- **Pattern:** [reusable code pattern if any]
```

### Task 2: 创建 PreToolUse hook — Read Before Decide

**Files:**
- Create: `hooks/feedback/inject-plan-context.sh`

每次 **write** 工具调用前（matcher: `write`，不是所有工具），如果 `docs/plans/.active` 存在且指向有效文件，读 plan 的 `## Checklist` section（不是前 30 行，精准提取 checklist）注入到 stderr。

**错误处理：** `.active` 不存在或指向无效文件 → 静默 exit 0，不影响工具执行。

**性能：** 只在 write 时触发，不影响 read/shell。grep checklist section 比 head -30 更精准且开销相当。

**防循环：** 检查写入目标文件，如果是 progress.md/findings.md 本身 → 跳过注入，避免干扰。

### Task 3: 创建 PostToolUse hook — 写文件提醒

**Files:**
- Create: `hooks/feedback/remind-update-progress.sh`

**matcher:** `write`（与 auto-test/auto-lint 相同 matcher，Kiro 按注册顺序执行，不冲突）

写文件后提醒："如果这完成了一个 checklist 项，更新 plan（勾选）和 progress.md（记录）"。

**防循环：** 检查写入目标文件，如果是 plan/progress.md/findings.md → 不提醒（避免无限循环）。

### Task 4: 注册 hooks 到配置

**Files:**
- Modify: `.kiro/agents/default.json`（在 preToolUse 和 postToolUse 数组中追加）
- Modify: `scripts/generate-platform-configs.sh`（同步）

## Checklist
- [x] `ralph-loop.sh` prompt 包含 progress.md 和 findings.md 读写规则及格式定义
- [x] `hooks/feedback/inject-plan-context.sh` 创建（PreToolUse[write]，注入 checklist section，有防循环和错误处理）
- [x] `hooks/feedback/remind-update-progress.sh` 创建（PostToolUse[write]，提醒更新，有防循环）
- [x] 两个 hook 注册到 `.kiro/agents/default.json` 和 `generate-platform-configs.sh`
- [x] hook 脚本可执行、无语法错误（`bash -n` 验证）

## Review (Round 1)

~~**VERDICT: REQUEST CHANGES**~~

Required changes (已解决):
1. ~~性能影响~~ → PreToolUse 只在 write 时触发，不影响 read/shell
2. ~~hook matcher 冲突~~ → 明确 matcher: write，与现有 hook 同 matcher 不冲突
3. ~~错误处理~~ → .active 无效时静默 exit 0
4. ~~文件格式定义~~ → 已添加 progress.md 和 findings.md 格式
5. ~~集成测试~~ → checklist 加了 bash -n 验证
6. ~~hook 执行顺序和循环~~ → 防循环检查：写入目标是 plan/progress/findings 时跳过

## Review (Round 2)
<!-- Reviewer writes here -->
