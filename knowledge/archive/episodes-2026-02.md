2026-02-13 | resolved | skill-chain,skip | 跳过skill-chain直接写代码 [hook: enforce-skill-chain]
2026-02-16 | resolved | subagent,reviewer,dispatch,bug | ~~错误归因: 以为省略agent_name找kiro_default不存在~~ 真因: availableAgents白名单只有["researcher","reviewer"], 内置default subagent被白名单拦截. Kiro官方文档确认省略agent_name用内置default subagent(kiro.dev/docs/cli/chat/subagents). reviewer dispatch仍需agent_name:"reviewer"
