# Ralph Loop 强约束 verify-completion 方案

**Goal:** 将 verify-completion 从 L3 advisory（~50% 遵从）升级为硬约束 — 利用 Ralph Loop 的 bash 外循环原理，agent 停了没关系，checklist 没勾完就重启新实例继续。

**Architecture:** `@execute` 命令调用 `ralph-loop.sh` bash 脚本，脚本循环启动 Kiro CLI 实例执行 plan 中的 checklist 项，每次迭代是 fresh context，直到所有项勾完。

**Tech Stack:** Bash + Kiro CLI (`--no-interactive --trust-all-tools`)

## Tasks

### Task 1: 重写 `commands/execute.md`

**Files:**
- Modify: `commands/execute.md`

改为：
1. 读 `docs/plans/.active` 找到 plan 文件
2. 验证 plan 有 `## Checklist` 且至少一个 `- [ ]`
3. 执行 `./scripts/ralph-loop.sh`
4. 脚本退出后报告结果，触发 finishing skill

### Task 2: 重写 `scripts/ralph-loop.sh`

**Files:**
- Modify: `scripts/ralph-loop.sh`

**内部 Kiro 实例的 prompt 模板：**
```
You are executing a plan. Read the plan file at {PLAN_FILE}.
Find the next unchecked item (- [ ]) in the ## Checklist section.
Implement that ONE item. Verify it works (run tests/typecheck).
Then update the plan file: change that item from - [ ] to - [x].
Commit with message: feat: {item description}.
Then find the next - [ ] item and repeat. Do NOT stop while unchecked items remain.
If stuck after 3 attempts on one item, change it to - [SKIP] with reason, move to next.
```

**错误处理策略：**
- Kiro 实例 exit 非 0 → 记录日志，继续下一轮（可恢复）
- plan 文件不存在/被删 → 立即退出（致命）
- 连续 3 轮 checklist 无变化（没有新的 `- [x]`）→ 退出，报告卡住（circuit breaker）

**Git 冲突处理：**
- 每轮开始前检查 `git status --porcelain`，有未提交变更则先 `git stash`
- 不处理 merge conflict（超出范围，需要人工介入）

### Task 3: 确认 `verify-completion.sh` 兼容

**Files:**
- Verify: `hooks/feedback/verify-completion.sh`

已使用 `find_active_plan()` 读 `.active` 指针，与新流程兼容。作为 advisory 补充层。

## Checklist
- [x] `commands/execute.md` 改为调用 ralph-loop.sh，不自己执行 task
- [x] `scripts/ralph-loop.sh` 用指定 prompt 模板启动内部 Kiro 实例，避免递归
- [x] `scripts/ralph-loop.sh` 有 circuit breaker（连续 3 轮无进展则退出）
- [x] `verify-completion.sh` 与 .active 指针兼容（已确认，无需改动）

## Review (Round 1)

~~**Verdict:** REQUEST CHANGES~~

Required fixes (已解决):
1. ~~Specify exact prompt template~~ → Task 2 已添加完整 prompt 模板
2. ~~Add error handling strategy~~ → Task 2 已添加三级错误处理
3. ~~Define timeout mechanism~~ → circuit breaker: 连续 3 轮无进展则退出
4. ~~Add git conflict resolution strategy~~ → 每轮开始前 stash，merge conflict 需人工

## Review (Round 2)

**Verdict:** APPROVE

All Round 1 fixes addressed:
1. ✅ Prompt template — complete and actionable
2. ✅ Error handling — three-level strategy (recoverable/fatal/circuit breaker)
3. ✅ Timeout — circuit breaker: 3 rounds no progress → exit
4. ✅ Git conflict — stash before each round, merge conflicts need human
