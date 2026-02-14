# Episodes (Episodic Memory)

> Timestamped events. ≤30 entries. Auto-captured by hook + manual via @reflect.

<!-- FORMAT: DATE | STATUS | KEYWORDS | SUMMARY -->
<!-- STATUS: active / resolved / promoted -->
<!-- Promotion candidates are computed at runtime (keyword freq ≥3), not stored -->

2026-02-13 | promoted | sed,json,jq | sed处理JSON→用jq, x10次, 已建hook [hook: block-sed-json]
2026-02-13 | promoted | stat,macos | macOS用stat-c→用stat-f, x3次
2026-02-13 | promoted | grep,exit-code | grep-c无匹配exit1但输出0, 不要和echo0组合
2026-02-13 | promoted | skill,injection,html | skill含HTML注释prompt injection [hook: scan-skill-injection]
2026-02-13 | promoted | hook,enforcement | 没有hook强制的行为=不会发生, x多次验证
2026-02-13 | active | kiro,subagent,hooks | Kiro子agent完全执行自定义hooks(实测确认)
2026-02-13 | active | kiro,shell,semantic | Kiro hook只支持command, 可curl调LLM API做语义判断
2026-02-13 | active | refactor,capability | 重构过度聚焦新功能, 差点丢失旧框架核心能力
2026-02-13 | active | nonfunctional,context,recovery | 设计缺失长时间运行挑战: context溢出/中断恢复/过早停止
2026-02-13 | resolved | skill-chain,skip | 跳过skill-chain直接写代码 [hook: enforce-skill-chain]
2026-02-13 | active | source-file,shell | is_source_file遗漏.sh/.yaml/.toml/.tf等
2026-02-14 | active | context-enrichment,soft-prompt | 软提醒被无视x2, 需升级为MANDATORY
2026-02-14 | active | reviewer,skip,plan | 写完plan跳过reviewer, 无hook=跳过
2026-02-14 | active | kiro,plan,builtin | Kiro内置/plan是黑盒, 不走自定义流程, 用@plan替代
2026-02-15 | active | symlink,fs_read,directory | fs_read Directory模式不支持symlink目录, 用ls或execute_bash替代
2026-02-15 | active | subagent,delegation,context | subagent选择性委派: 能力不降级/结果自包含/任务独立, 需要code/grep/web工具的不委派
2026-02-15 | active | kiro,subagent,tools,boundary | Kiro subagent工具硬限制(官方文档确认): 可用=read/write/shell/MCP; 不可用=web_search/web_fetch/introspect/thinking/todo_list/use_aws/grep/glob/code. 配了也没用, 运行时直接不可用. resources(file://+skill://)是agent spawn时加载到context的, 不受工具限制影响. 来源: kiro.dev/docs/cli/chat/subagents + kiro.dev/docs/cli/custom-agents/configuration-reference
2026-02-15 | active | kiro,subagent,mcp,capability | MCP补能力方案: ripgrep(grep替代), filesystem(glob替代), brave-search(web_search替代), fetch(web_fetch替代). code tool(LSP)无MCP替代. 已验证: subagent spawn时mcpServers正确启动, ripgrep MCP工具完全可用(search/advanced-search/count-matches/list-files等). agent JSON修改即时生效, 但default.json的availableAgents白名单是session级别的
2026-02-15 | active | kiro,subagent,architecture | 4 agent→2 agent优化: 删除implementer/debugger(ralph-loop独立进程更强), 保留reviewer+researcher(MCP补能力). workspace mcp.json加ripgrep, researcher加fetch MCP
2026-02-15 | active | kiro,mcp,includeMcpJson | workspace mcp.json不会自动被subagent继承! 必须在agent JSON中设置`includeMcpJson: true`才能继承workspace和global mcp.json中的MCP servers(默认false). 来源: kiro.dev/docs/cli/custom-agents/configuration-reference + kiro.dev/docs/cli/mcp
2026-02-15 | active | fetch,mcp,socksio,proxy | fetch MCP(mcp-server-fetch)在SOCKS代理环境下需要socksio包. 修复: uvx args改为["--with", "socksio", "mcp-server-fetch"]. MCP server进程在session内不会自动重启, 配置变更需新session生效
