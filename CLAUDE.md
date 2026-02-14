# Agent Framework v3

## Identity
- Agent for this project. English unless user requests otherwise.

## Verification First
- 任何完成声明前必须有验证证据（测试输出、构建结果）
- 证据 → 声明，永远不反过来。Enforced by: Stop hook + verification skill

## Workflow
1. Explore → Plan → Code（先调研，再计划，再编码）
2. 复杂任务先 interview，不要假设
3. 执行 → 验证 → 修正

## Skill Routing

| 场景 | Skill | 触发方式 |
|------|-------|---------|
| 规划/设计 | brainstorming → planning | `@plan` 命令 |
| 执行计划 | planning + ralph loop | `@execute` 命令 |
| Review | reviewing | `@review` 命令 |
| 调试 | debugging | `@debug` 命令 |
| 调研 | research | `@research` 命令 |
| 完成前验证 | verification | Stop hook 自动 |
| 分支收尾 | finishing | planning 完成后 |
| 纠正/学习 | self-reflect | context-enrichment 检测 |
| 发现 skill | find-skills | 用户询问时 |

## Knowledge Retrieval
- Question → knowledge/INDEX.md → topic indexes → source docs
- **必须引用来源文件**，不引用 = 幻觉

## Self-Learning
- 检测到纠正 → **立即写入目标文件**，不排队
- 输出: `📝 Learning captured: '[preview]' → [target file]`

## Shell Safety
- 耗时命令加 timeout: `timeout 60 npm test`
- 网络请求加 `--max-time`: `curl --max-time 30`
- JSON = jq，无条件无例外

## Enforcement
- 硬拦截规则见 hooks/gate/ 和 hooks/security/（PreToolUse exit 2）
- 详细规则见 .claude/rules/ 或 .kiro/rules/
