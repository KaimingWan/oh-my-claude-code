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
2026-02-16 | resolved | subagent,reviewer,dispatch,bug | ~~错误归因: 以为省略agent_name找kiro_default不存在~~ 真因: availableAgents白名单只有["researcher","reviewer"], 内置default subagent被白名单拦截. Kiro官方文档确认省略agent_name用内置default subagent(kiro.dev/docs/cli/chat/subagents). reviewer dispatch仍需agent_name:"reviewer"
2026-02-16 | active | config,drift,generator | generate-platform-configs.sh重新生成会覆盖手动编辑的JSON. enforce-ralph-loop.sh在c902220手动注册到default.json, 被a27860d的config generator覆盖丢失. 教训: 所有hook注册必须加到generator脚本, 不能只手动改JSON
2026-02-16 | active | subagent,availableAgents,whitelist | availableAgents白名单限制subagent spawn范围. 省略agent_name时用Kiro内置default subagent, 但如果availableAgents不含通配符或内置default, 会被拦截. 需要执行task的subagent必须在白名单中
2026-02-16 | active | subagent,reviewer,parallel,performance | Plan review应1批4个reviewer并发, 不是2批×2个. 同一agent_name可spawn多个实例. use_subagent限制是每次调用最多4个subagent, 不是4个不同agent. 拆批会串行等待浪费时间
2026-02-16 | active | ralph-loop,stash,data-loss | ralph-loop.sh在iter开始前git stash dirty state, 但subagent在新实例工作不会pop stash. 当前会话的未commit改动会丢失. 教训: 跑ralph-loop前先commit所有改动
2026-02-16 | active | enforce-ralph-loop,absolute-path,hook,bug | enforce-ralph-loop.sh的fs_write allowlist用相对路径pattern(docs/plans/*.md)但Kiro传入绝对路径, case glob不匹配导致合法写入被误拦. 修复: 在allowlist检查前用git rev-parse --show-toplevel剥离workspace前缀转为相对路径. 同时发现bash allowlist中包含.active的命令也被误拦(grep '.active'匹配). 教训: hook收到的路径格式必须实测验证, 不能假设
2026-02-16 | active | ralph-loop,orphan,sleep,fd,pipe | ralph-loop.sh的heartbeat/watchdog subshell内直接调sleep, kill subshell后sleep变孤儿(PPID=1)继承stdout/stderr fd, 导致调用方(execute_bash/kiro-cli)等管道关闭时永久卡住. 表现: ralph-loop报SUCCESS但调用方不返回. 修复: subshell内sleep改后台执行(`sleep N &; wait $!`)+`trap 'kill %% 2>/dev/null' EXIT`, subshell被kill时trap触发杀sleep, 无孤儿无fd泄漏. 教训: bash subshell内长时间sleep必须可被父进程连带清理, 直接sleep会产生不可控孤儿
2026-02-16 | active | enforce-ralph-loop,checklist,grep,false-positive | enforce-ralph-loop.sh用`grep -c '^\- \[ \]'`扫整个plan文件计数unchecked items, 但plan文件内嵌的代码示例/test fixture也包含`- [ ]`文本, 导致已完成的plan被误判为未完成, 所有命令被拦截. 修复: 用awk只提取最后一个`## Checklist` section再grep. 教训: plan文件是混合内容(markdown+嵌入代码), 结构化提取必须限定section范围, 不能全文grep
2026-02-16 | active | reviewer,context,calibration,prompt | Reviewer反复提低价值反馈(rollback/encoding/file existence)被主agent驳回, 浪费token. 三层根因: ①reviewer prompt要求"每Task必须提2个missed scenario"+"缺项自动REQUEST CHANGES", 激励过度挑剔 ②calibration标准写在planning skill里但reviewer看不到(resources不含planning skill) ③传摘要plan导致reviewer缺上下文瞎猜. 修复: reviewer-prompt.md加calibration标准+去掉强制挑刺条款, subagent.md加规则传路径让reviewer自读文件, planning skill同步更新dispatch步骤.
2026-02-17 | active | reviewer,verify,semantics | Reviewer审verify命令时只看语法不理解意图: diff返回0=相同=验证通过, reviewer说应该用`! diff -q`(逻辑反转). 修复: reviewer-prompt加"Verify Command Review"节, 要求先理解intent再检查correctness, 手动trace exit code
2026-02-17 | active | reviewer,prompt,calibration,research | Reviewer prompt全面重写基于调研: ①Google eng practices核心原则"favor approving when it improves code health"+Nit前缀 ②强制finding格式(problem+impact+fix三要素, 缺一不可) ③anchor examples(好finding vs 坏finding对比) ④severity只分P0/P1/Nit三级, 只有P0/P1能REQUEST CHANGES ⑤verify command review要求先理解intent再trace exit code ⑥去掉devil's advocate/challenge every decision等激励过度挑剔的措辞
2026-02-17 | active | ralph,regression,testing | Ralph有完整回归测试套件(76 tests): `pytest tests/ralph-loop/ -v`。改ralph相关代码(scripts/ralph_loop.py, scripts/lib/plan.py, scripts/lib/scheduler.py, scripts/lib/lock.py)必须跑回归。enforcement hook测试: `bash tests/ralph-loop/test-enforcement.sh`
2026-02-18 | active | reviewer,rubber-stamp,quality,prompt | Plan review Round 1 质量低: Verify Correctness给blanket APPROVE无逐条trace, Goal Alignment机械贴标签无深入质疑, Clarity快速APPROVE无真正dry-run. 三层根因: ①reviewer-prompt.md缺少"必须展示工作过程"的强制要求(只说了format但没要求show-your-work) ②dispatch query的Mission段直接复制planning skill的angle description, 太抽象, reviewer不知道具体要输出什么 ③Completeness angle的mission描述没有scope guard, reviewer把"plan没测试现有函数"当缺陷(超出Non-Goals)
2026-02-18 | active | reviewer,template,fill-blank,quality | Reviewer subagent两轮实测: "请输出表格"仍被忽略(Verify Correctness两轮都blanket APPROVE), 但"复制这个表格并填空每个cell"有效(Technical Feasibility和Testability质量好). 根因: subagent context有限+无hook强制, 只能靠prompt约束. 改进: 固定angle的mission改为预填模板+填空式, 降低偷懒可能. reviewer-prompt.md加"Fill the template"规则: dispatch query包含表格模板时必须逐cell填写, 跳过=review REJECTED

2026-02-18 | active | hook,enforce-ralph-loop,ordering,bug | enforce-ralph-loop.sh的chaining/pipe检查在read-only allowlist之前执行, 导致合法的只读pipe(`grep|head`)和stderr redirect(`unlink 2>/dev/null||true`)被误拦. 修复: 提取FIRST_CMD, 先匹配read-only allowlist(允许pipe到其他只读命令), 再做chaining兜底检查. 教训: gate hook的检查顺序很重要——先allowlist再blocklist, 否则合法操作被误杀
2026-02-18 | active | cc,headless,auth,testing | `claude -p`(headless模式)需要预先认证, 不能像交互模式那样自动弹OAuth. `claude auth status`显示loggedIn:false时, `-p`直接exit 1. 解决: 设`ANTHROPIC_API_KEY`环境变量, 或SSH端口转发做OAuth. Plan里的detect_cli()必须验证auth状态, 未认证fallback到Kiro
2026-02-18 | active | cc,macos,timeout,compatibility | macOS没有`timeout`命令(GNU coreutils). Plan里写`timeout 60s`在macOS上会command not found. 替代: `gtimeout`(brew install coreutils)或`perl -e 'alarm(N); exec @ARGV'`. 所有跨平台bash脚本不能假设timeout存在
2026-02-18 | active | cc,allowedTools,subagent,Task | CC headless模式的`--allowedTools`必须显式包含`Task`才能派发subagent. 最初plan只写了`Bash,Read,Write,Edit`, 导致reviewer/executor subagent无法被派发. 还需要`WebSearch,WebFetch`给researcher. 教训: allowedTools是白名单, 遗漏=功能缺失
2026-02-18 | active | cc,PermissionRequest,headless | CC官方文档明确: `PermissionRequest` hooks在`-p`(非交互)模式下不触发. 我们的hooks全用PreToolUse所以不受影响, 但集成测试不能测PermissionRequest相关行为
2026-02-18 | active | testing,coverage,require-regression | test-kiro-compat.sh遗漏了require-regression.sh(已wired在settings.json和pilot.json). Plan Task 5必须从settings.json枚举所有wired hooks, 不能只镜像现有测试文件. 教训: 测试覆盖矩阵要对照config源, 不能对照已有测试
