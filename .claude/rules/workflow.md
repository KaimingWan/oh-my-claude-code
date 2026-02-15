# Workflow Rules
# Layer: Agent Rule (top-level principles + operational rules)
# Maintained by: humans only (hook enforced)
# Boundary: universal rules, not project-specific learnings

1. 教训记录不等于修复。反复犯错（≥3次）→ 必须升级为 hook 拦截。
2. 收到任务第一步：读 context-enrichment 输出，按提示走，不跳过。
3. 重构时逐项检查旧能力是否被覆盖，不能只关注新增。
4. 非功能性需求（性能、可靠性、长时间运行）必须和功能性需求同等对待。
5. 方案 review 必须用真实场景 corner case 检验，不能只看 happy path。
6. 文档不确定的能力要实测验证，不要猜。
7. 没有 hook 强制的步骤 agent 就会跳过。所有强制约束必须映射到 hook。
8. 用自定义 @plan 替代平台内置 /plan，确保走自定义 skill chain + reviewer。
9. Checklist 勾选必须有 verify 命令执行证据（10 分钟内 exit 0），hook 强制。格式：`- [ ] desc | \`verify cmd\``。
