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
