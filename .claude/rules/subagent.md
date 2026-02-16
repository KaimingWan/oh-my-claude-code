# Subagent Rules
# Layer: Agent Rule (top-level principles + operational rules)
# Maintained by: humans only (hook enforced)
# Boundary: universal rules, not project-specific learnings

1. Kiro subagent 只能用 read/write/shell/MCP 四类工具。web_search/web_fetch/code/grep/glob/use_aws/introspect/thinking/todo_list 均不可用，配了也无效。但 MCP 可补回部分能力（ripgrep→grep, fetch→web_fetch）。resources（file://+skill://）是 spawn 时加载的 context，不受此限制。
2. dispatch reviewer/researcher 时必须指定 `agent_name`（如 `"reviewer"`, `"researcher"`）。省略 agent_name 时 Kiro 用内置 default subagent，但会受 `availableAgents` 白名单限制——如果白名单不含通配符或内置 default，会被拦截。task execution subagent 推荐创建专用 executor agent 并指定 agent_name。
3. MCP 补能力已验证可行：ripgrep MCP 在 subagent 中完全可用（实测确认）。架构：workspace mcp.json 放 ripgrep（所有 subagent 继承），researcher agent JSON 放 fetch MCP。**必须在 agent JSON 中设 `includeMcpJson: true` 才能继承 workspace mcp.json**（默认 false）。code tool（LSP）无法通过 MCP 补回，需要 LSP 的任务永远不委派给 subagent。
4. executor subagent 用于 plan task 并行执行。必须指定 agent_name: "executor"。executor 只做实现+验证，不改 plan 文件，不 git commit。主 agent 统一收尾（更新 plan、commit、progress）。verify log 由 executor 的 post-bash.sh hook 写入，主 agent 勾选 checklist 时 gate_checklist 能找到记录。
5. dispatch reviewer 时传 plan 文件路径（不传内容），由 reviewer 自行读取完整 plan 文件。禁止在 query 中摘要/精简 plan。原因：传完整内容会导致 4 路并行超出 payload 限制；reviewer 有 read/shell 工具可自行读文件；摘要会导致误判（已发生 2 次，见 episodes.md）。
