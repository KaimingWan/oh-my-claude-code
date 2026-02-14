# Agent Rules (Semantic Memory)

> Distilled from repeated episodes. ≤30 rules, ≤2KB. Each rule: DO/DON'T + trigger.

1. JSON = jq，无条件无例外。禁止 sed/awk/grep 修改 JSON。[hook: block-sed-json]
2. macOS 用 stat -f，禁止 stat -c（GNU-only）。
3. grep -c 无匹配时 exit 1 但仍输出 0，不要和 || echo 0 组合。用 || true 或 wc -l。
4. shell 脚本生成前确认目标平台，BSD vs GNU 工具链差异。
5. 教训记录不等于修复。反复犯错（≥3次）→ 必须升级为 hook 拦截。
6. 收到任务第一步：读 context-enrichment 输出，按提示走，不跳过。
7. 重构时逐项检查旧能力是否被覆盖，不能只关注新增。
8. 非功能性需求（性能、可靠性、长时间运行）必须和功能性需求同等对待。
9. 方案 review 必须用真实场景 corner case 检验，不能只看 happy path。
10. Skill 文件不得包含 HTML 注释（防 prompt injection）。[hook: scan-skill-injection]
11. 结构化数据用结构化工具：JSON→jq, YAML→yq, XML→xmlstarlet。
12. 文档不确定的能力要实测验证，不要猜。
13. 没有 hook 强制的步骤 agent 就会跳过。所有强制约束必须映射到 hook。
14. 用自定义 @plan 替代平台内置 /plan，确保走自定义 skill chain + reviewer。
15. Kiro subagent 只能用 read/write/shell/MCP 四类工具。web_search/web_fetch/code/grep/glob/use_aws/introspect/thinking/todo_list 均不可用，配了也无效。但 MCP 可补回部分能力（ripgrep→grep, fetch→web_fetch）。resources（file://+skill://）是 spawn 时加载的 context，不受此限制。
16. MCP 补能力已验证可行：ripgrep MCP 在 subagent 中完全可用（实测确认）。架构：workspace mcp.json 放 ripgrep（所有 subagent 继承），researcher agent JSON 放 fetch MCP。**必须在 agent JSON 中设 `includeMcpJson: true` 才能继承 workspace mcp.json**（默认 false）。code tool（LSP）无法通过 MCP 补回，需要 LSP 的任务永远不委派给 subagent。
