# Agent Rules (Long-term Memory)

> Distilled from episodes. No cap. Organized by keyword sections.
> Sections emerge naturally from episode keywords during promotion.

## [shell, json, jq, bash, stat, sed, awk, gnu, bsd, yaml, xml]
1. JSON = jq，无条件无例外。禁止 sed/awk/grep 修改 JSON。[hook: block-sed-json]
2. macOS 用 stat -f，禁止 stat -c（GNU-only）。
3. grep -c 无匹配时 exit 1 但仍输出 0，不要和 || echo 0 组合。用 || true 或 wc -l。
4. shell 脚本生成前确认目标平台，BSD vs GNU 工具链差异。
5. 结构化数据用结构化工具：JSON→jq, YAML→yq, XML→xmlstarlet。

## [security, hook, injection, workspace, sandbox, secret]
1. Skill 文件不得包含 HTML 注释（防 prompt injection）。[hook: scan-skill-injection]
2. Workspace 边界防护是应用层 hook，只能拦截 tool call 层面的写入（fs_write 路径检查 + bash 正则模式检测）。无法拦截子进程内部行为。完全防护需 OS 级沙箱（macOS Seatbelt / Docker）。NVIDIA AI Red Team 三个 mandatory controls：网络出口控制、阻止 workspace 外写入、阻止配置文件写入。

## [workflow, plan, review, skill, refactor, verify, test, commit]
1. 教训记录不等于修复。反复犯错（≥3次）→ 必须升级为 hook 拦截。
2. 收到任务第一步：读 context-enrichment 输出，按提示走，不跳过。
3. 重构时逐项检查旧能力是否被覆盖，不能只关注新增。
4. 非功能性需求（性能、可靠性、长时间运行）必须和功能性需求同等对待。
5. 方案 review 必须用真实场景 corner case 检验，不能只看 happy path。
6. 文档不确定的能力要实测验证，不要猜。
7. 没有 hook 强制的步骤 agent 就会跳过。所有强制约束必须映射到 hook。
8. 用自定义 @plan 替代平台内置 /plan，确保走自定义 skill chain + reviewer。
9. Checklist 勾选必须有 verify 命令执行证据（10 分钟内 exit 0），hook 强制。格式：`- [ ] desc | \`verify cmd\``。

## [subagent, mcp, kiro, delegate, capability, tool]
1. Kiro subagent 只能用 read/write/shell/MCP 四类工具。web_search/web_fetch/code/grep/glob/use_aws/introspect/thinking/todo_list 均不可用，配了也无效。但 MCP 可补回部分能力（ripgrep→grep, fetch→web_fetch）。resources（file://+skill://）是 spawn 时加载的 context，不受此限制。
2. MCP 补能力已验证可行：ripgrep MCP 在 subagent 中完全可用（实测确认）。架构：workspace mcp.json 放 ripgrep（所有 subagent 继承），researcher agent JSON 放 fetch MCP。**必须在 agent JSON 中设 `includeMcpJson: true` 才能继承 workspace mcp.json**（默认 false）。code tool（LSP）无法通过 MCP 补回，需要 LSP 的任务永远不委派给 subagent。

## [debugging, bug, error, failure, fix, broken]
1. 修 bug 前必须先复现、定位根因，禁止猜测性修复。NO FIX WITHOUT ROOT CAUSE。
2. 遇到测试失败：先读完整错误信息和堆栈，再行动。
3. 连续修 3 次不成功 → 停下来，重新从复现开始。
