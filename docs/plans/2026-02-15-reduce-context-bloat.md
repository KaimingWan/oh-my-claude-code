# Reduce Context Bloat — Hook Merge + Subagent Strategy

**Goal:** 减少对话膨胀速度，缓解 Kiro CLI compaction 失败问题。合并 hooks 降低消息数，优化 subagent 执行策略隔离重活。

**Architecture:** 将 postToolUse 3 个 hooks 合并为 `post-write.sh`，preToolUse 3 个合并为 `pre-write.sh`（security hooks 保持独立）。在 planning skill 中增加 subagent 执行阈值规则。

**Tech Stack:** Bash (hooks), Markdown (skill docs), JSON (agent config)

## Tasks

### Task 1: 合并 postToolUse hooks → post-write.sh

将 `auto-test.sh` + `auto-lint.sh` + `remind-update-progress.sh` 合并为单文件 `hooks/feedback/post-write.sh`。

**Files:**
- Create: `hooks/feedback/post-write.sh`
- Modify: `.kiro/agents/default.json` (postToolUse 改为单条)
- Modify: `.kiro/agents/implementer.json` (postToolUse 同步)

**Error handling:** 各函数独立 try-catch，一个失败不影响其他。lint/remind 失败静默，test 失败才 exit 1。

**Steps:**
1. 创建 `post-write.sh`，包含三个函数：`run_lint`、`run_test`、`remind_progress`，每个函数内部捕获错误
2. 更新 `default.json` postToolUse 从 3 条 → 1 条
3. 更新 `implementer.json` postToolUse 同步
4. 测试：`echo '{"tool_name":"fs_write","tool_input":{"file_path":"test.ts"}}' | bash hooks/feedback/post-write.sh`

### Task 2: 合并 preToolUse hooks → pre-write.sh

将 `require-workflow.sh` + `scan-skill-injection.sh`（在 security/ 下）+ `inject-plan-context.sh`（在 feedback/ 下）合并为 `hooks/gate/pre-write.sh`。Security hooks for execute_bash 保持独立不动。

**Files:**
- Create: `hooks/gate/pre-write.sh`
- Modify: `.kiro/agents/default.json` (preToolUse fs_write 从 3 条 → 1 条)

**Error handling:** gate check (require-workflow) 失败 → exit 2 硬拦截。injection scan 失败 → exit 2。plan context inject 失败 → 静默 exit 0（advisory only）。

**Steps:**
1. 创建 `pre-write.sh`，三阶段顺序执行：gate check → injection scan → plan context inject
2. 更新 `default.json` preToolUse
3. 测试：确认无 plan 时 gate 拦截仍 exit 2

### Task 3: 更新 planning skill — subagent 执行阈值

在 `skills/planning/SKILL.md` 的 Phase 2 执行策略中，增加明确的 subagent 触发规则。

**Files:**
- Modify: `skills/planning/SKILL.md`

**Steps:**
1. 在 Phase 2 开头增加执行策略选择规则：
   - checklist ≤3 项 → Strategy A (主对话顺序执行)
   - checklist >3 项 → Strategy C (subagent per task)
   - 2+ 独立无依赖任务 → Strategy B (并行 subagent)
2. 确保规则简洁，不超过 10 行

### Task 4: 清理旧 hook 文件

合并完成且验证通过后，删除被合并的旧文件。

**Files:**
- Delete: `hooks/feedback/auto-test.sh`
- Delete: `hooks/feedback/auto-lint.sh`
- Delete: `hooks/feedback/remind-update-progress.sh`
- Delete: `hooks/feedback/inject-plan-context.sh`
- Delete: `hooks/gate/require-workflow.sh`
- Delete: `hooks/security/scan-skill-injection.sh`

**Steps:**
1. `grep -r 'auto-test\|auto-lint\|remind-update-progress\|inject-plan-context\|require-workflow\|scan-skill-injection' --include='*.json' --include='*.sh' --include='*.md' .` 确认无残留引用
2. `git rm` 旧文件
3. 如果发现残留引用，先修复再删除

**Rollback:** 所有旧文件在 git 历史中可恢复，`git checkout HEAD~1 -- hooks/feedback/auto-test.sh` 等即可回退。

## Review

### Round 1: REQUEST CHANGES (addressed)
~~Missing error handling, rollback, file location inconsistency, dependency verification.~~
All fixed in plan revision: error handling per-function, rollback via git history, correct file paths, grep verification step added.

### Round 2: APPROVE

**Round 1 Issues Resolution:**
✅ **Error handling:** Each function has independent error handling, lint/remind fail silently, only test failure exits 1
✅ **Rollback:** Git history rollback documented with specific commands
✅ **File location inconsistency:** Correct paths noted (scan-skill-injection in security/, inject-plan-context in feedback/)
✅ **Dependency verification:** grep step added before deletion to check for remaining references
✅ **No backup:** Git history serves as backup mechanism

**Critical:** None identified
**Warning:** None identified  
**Suggestion:** Plan is well-structured and addresses all previous concerns comprehensively

**Verdict: APPROVE** - All Round 1 issues properly resolved, implementation approach is sound

## Checklist

- [x] `hooks/feedback/post-write.sh` 创建，包含 lint + test + remind 三个功能
- [x] `hooks/gate/pre-write.sh` 创建，包含 workflow gate + injection scan + plan context
- [x] `default.json` postToolUse 从 3 条 → 1 条
- [x] `default.json` preToolUse[fs_write] 从 3 条 → 1 条
- [x] `implementer.json` postToolUse 同步更新
- [x] Security hooks (block-dangerous/block-secrets/block-sed-json) 保持独立不变
- [x] `skills/planning/SKILL.md` 增加 subagent 执行阈值规则
- [x] 旧 hook 文件已删除，无残留引用
- [x] gate check (exit 2 拦截) 在合并后仍然生效
