<!-- BEGIN OMCC WORKFLOW -->
## Workflow
- Explore → Plan → Code（先调研，再计划，再编码）
- 复杂任务先 interview，不要假设

## Skill Routing

| 场景 | Skill | 触发方式 | 加载方式 |
|------|-------|---------|---------|
| 规划/设计 | planning | `@plan` 命令 | 预加载 |
| 执行计划 | planning + ralph loop | `@execute` 命令 | 预加载 |
| Code Review | reviewing | `@review` 命令 | 预加载 |
| 调试 | debugging | rules.md 自动注入 | 按需读取 |
| 调研 | research | `@research` 命令 | 按需读取 |
| 完成前验证 | verification | Stop hook 自动 | 按需读取 |
| 分支收尾 | finishing | planning 完成后 | 按需读取 |
| 纠正/学习 | self-reflect | context-enrichment 检测 | 按需读取 |
| 发现 skill | find-skills | 用户询问时 | 按需读取 |

## Knowledge Retrieval
- Question → knowledge/INDEX.md → topic indexes → source docs
<!-- END OMCC WORKFLOW -->
