# Agent Framework v2

## Identity
- Agent for [Project Name]. English unless user requests otherwise.

## Verification First (最高优先级)
- 任何完成声明前必须有验证证据（测试输出、构建结果）
- 证据 → 声明，永远不反过来
- Enforced by: Stop hook (CC: agent type / Kiro: command + LLM eval)

## Workflow
1. Explore → Plan → Code (先调研，再计划，再编码)
2. 复杂任务先 interview，不要假设
3. 执行 → 验证 → 修正

## Skill Routing
- 规划/设计 → brainstorming skill → writing-plans skill → reviewer 辩证
- 执行 plan → executing-plans skill 或 dispatching-parallel-agents skill
- 完成/合并 → verification-before-completion skill → reviewer 验收 → code-review-expert skill
- 调试 → systematic-debugging skill (NO fixes without root cause)
- 调研 → research skill (web search → structured findings)
- 纠正/学习 → self-reflect skill (写入正确的目标文件)

## Plan as Living Document
- Plan 文件（docs/plans/*.md）是唯一事实来源，不是对话
- 每次讨论产生的决策变更，必须立即更新到 plan 文件
- 修改 plan 时标记 ~~废弃~~ 并说明原因，不要删除旧决策
- Context 压缩后，重新读 plan 文件恢复上下文

## Knowledge Retrieval
- Question → knowledge/INDEX.md → topic indexes → source docs
- **必须引用来源文件**，不引用 = 幻觉
- @knowledge/lessons-learned.md — 每次任务前后必查
- Enforced by: context-enrichment hook + Stop hook

## Compound Interest (自动沉淀)
1. **结构化输出必须写入文件** — 不只是聊天输出
2. **操作重复 ≥3 次** → 提示创建模板/工具 (Toolify First)
3. **任务完成后** → 检查索引是否需要更新

## Self-Learning (自进化)
- 检测到纠正 → **立即写入目标文件**，不排队
- 输出: `📝 Learning captured: '[preview]'`
- 同步目标: 可编码→hooks | 高频→本文件 | 低频→knowledge/
- Enforced by: UserPromptSubmit hook (检测纠正模式 → 注入提醒)

## Long-Running Tasks
- 长任务开始时写 `.completion-criteria.md`（目标 + 检查清单）
- 这是持久化状态，context 压缩后重新读取恢复上下文
- 优先拆分为子 agent 短任务，而非单 agent 长跑

## Shell Safety
- 耗时命令加 timeout: `timeout 60 npm test`
- 网络请求加 `--max-time`: `curl --max-time 30`
- 禁止裸跑交互式命令，必须加 auto-answer flag

## Rules
- 详细规则见 .claude/rules/ 目录（自动加载）
- 安全规则由 hooks 强制执行，不依赖 prompt 遵从
