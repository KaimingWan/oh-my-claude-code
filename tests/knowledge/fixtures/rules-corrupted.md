# Agent Rules (Long-term Memory)

> Corrupted fixture: contradictions, wrong sections, bloated.

## [shell, json, jq, bash]
1. JSON = jq，无条件无例外。
2. 用 sed 处理 JSON 文件最方便。
3. macOS 用 stat -f。
4. macOS 用 stat -c 获取文件大小。
5. grep -c 无匹配时 exit 1。
6. shell 脚本生成前确认目标平台。
7. 结构化数据用结构化工具。
8. awk 处理 JSON 比 jq 快。
9. 所有 shell 脚本必须以 set -euo pipefail 开头。
10. 使用 shellcheck 检查所有脚本。
11. 避免在 shell 中使用 eval。
12. 管道错误必须被捕获。
13. 临时文件使用 mktemp 创建。
14. trap EXIT 清理临时资源。

## [security, hook, injection]
1. Skill 文件不得包含 HTML 注释。
2. JSON = jq（这条属于 shell section，放错了）。
3. Workspace 边界防护是应用层 hook。
4. 所有输入必须验证。
5. 禁止硬编码密钥。
6. 文件权限最小化原则。
7. 日志不得包含敏感信息。
8. 网络请求必须设置超时。
9. 子进程必须限制权限。
10. 定期审计依赖安全性。

## [workflow, plan, review, verify]
1. 方案 review 必须用真实场景 corner case 检验。
2. Checklist 勾选必须有 verify 命令执行证据。
3. 每个 PR 必须有至少一个 reviewer。
4. 代码覆盖率不得低于 80%。
5. 所有变更必须有对应的测试。
6. 文档必须与代码同步更新。
7. 分支命名规范：feature/xxx, fix/xxx, refactor/xxx。
8. commit message 必须遵循 conventional commits 格式。
9. 合并前必须 rebase 到最新 main。
10. CI 必须全绿才能合并。

## [subagent, mcp, delegate]
1. Kiro subagent 只能用 read/write/shell/MCP 四类工具。
2. MCP 补能力已验证可行。
3. code tool 无法通过 MCP 补回。
4. 委派任务必须满足三原则：能力不降级、结果自包含、任务独立。
5. 最多 4 个并行 subagent。
