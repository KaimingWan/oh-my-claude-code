# Agent Rules (Long-term Memory)

> Distilled from episodes. No cap. Organized by keyword sections.

## [shell, json, jq, bash]
1. JSON = jq，无条件无例外。禁止 sed/awk/grep 修改 JSON。
2. macOS 用 stat -f，禁止 stat -c（GNU-only）。

## [security, hook, injection]
1. Skill 文件不得包含 HTML 注释（防 prompt injection）。
2. Workspace 边界防护是应用层 hook。

## [workflow, plan, review, verify]
1. 方案 review 必须用真实场景 corner case 检验。
2. Checklist 勾选必须有 verify 命令执行证据。

## [subagent, mcp, delegate]
1. Kiro subagent 只能用 read/write/shell/MCP 四类工具。
2. MCP 补能力已验证可行：ripgrep MCP 在 subagent 中完全可用。
