# Episodes (Episodic Memory)

> Timestamped events. ≤30 entries. Auto-captured by hook + manual via @reflect.

<!-- FORMAT: DATE | STATUS | KEYWORDS | SUMMARY -->
<!-- STATUS: active / resolved / promoted -->
<!-- Promotion candidates are computed at runtime (keyword freq ≥3), not stored -->

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
2026-02-15 | active | security,workspace,hook | workspace边界防护: block-outside-workspace.sh拦截workspace外文件写入. fs_write用realpath+python3 normpath检查路径, bash用正则检测外部写入模式(>/>>重定向/tee/cp/mv/tar -C). git root fallback PWD, fail-closed. 所有agent统一挂载. 应用层hook只防误操作, OS级攻击需seatbelt/docker沙箱
2026-02-15 | active | knowledge-v2,rules,memory | 知识库v2: rules.md改为keyword section结构(## [kw1,kw2,...]), context-enrichment按消息关键词匹配section按需注入, promoted episodes自动清除(遗忘机制). 聚类由agent在self-reflect中语义判断, section自然涌现不预定义
2026-02-15 | active | tdd-checklist,verify,hook,plan | TDD checklist enforcement实现: 4层防护(plan结构检查→reviewer覆盖率审查→执行阶段hook拦截无证据勾选→stop hook重跑verify). 每个checklist项格式`- [ ] desc | \`cmd\``, 勾选前必须有cmd的成功执行记录(10分钟窗口). pipe while loop的exit在subshell中丢失, 必须用process substitution `< <(...)`
2026-02-16 | active | plan,review,verification | Plan review跳过Round 3: 修复reviewer反馈后自行判定"改好了"跳过验证轮次. 违反"证据→声明"原则. 规则: fix后必须re-dispatch reviewer, all APPROVE in one round才能停, 不能自行判定通过
2026-02-16 | active | plan,review,subagent,context | Plan review packet太精简(只传header+checklist+3句摘要)导致reviewer误判率高: 看不到Task完整代码/执行顺序/Create标注. 修复: 改为传完整plan文件给reviewer, 避免摘要过程丢失细节
2026-02-16 | active | subagent,reviewer,dispatch,bug | use_subagent必须指定agent_name: 不指定时默认找'kiro_default'(不存在)而非.kiro/agents/default.json. reviewer dispatch必须用agent_name:"reviewer". 已修复planning SKILL.md和reviewing SKILL.md加明确说明
2026-02-16 | active | subagent,reviewer,parallel,performance | Plan review应1批4个reviewer并发, 不是2批×2个. 同一agent_name可spawn多个实例. use_subagent限制是每次调用最多4个subagent, 不是4个不同agent. 拆批会串行等待浪费时间
2026-02-16 | active | ralph-loop,stash,data-loss | ralph-loop.sh在iter开始前git stash dirty state, 但subagent在新实例工作不会pop stash. 当前会话的未commit改动会丢失. 教训: 跑ralph-loop前先commit所有改动
