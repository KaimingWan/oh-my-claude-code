# Agent Rules — Staging Area

> Auto-distilled from episodes. Injected by context-enrichment per message.
> 🔴 = CRITICAL (always injected) | 🟡 = RELEVANT (keyword-matched)
> Sections auto-created by distill.sh. Max 5 rules per section.

## [memory,formation,hot-path,background]
🟡 1. 记忆形成两种时机: hot-path(对话中实时,即时生效但增加延迟)适合关键纠正; background(对话后异步,不影响响应)适合模式发现和规则蒸馏. 当前auto-capture=hot-path, session-init=background, 组合合理但缺background阶段的自动蒸馏. 来源: langchain-ai.github.io/langmem concepts
## [cc,macos,timeout,compatibility]
🔴 1. macOS没有`timeout`命令(GNU coreutils). Plan里写`timeout 60s`在macOS上会command not found. 替代: `gtimeout`(brew install coreutils)或`perl -e 'alarm(N); exec @ARGV'`. 所有跨平台bash脚本不能假设timeout存在
## [research,socratic,depth,compaction]
🔴 1. 调研复杂问题(long-running agent优化)时跳过苏格拉底自检直接输出6个优化方向. 根因: 调研后进入"拿锤子找钉子"模式——看到论文说X是问题就认为框架也有X问题, 没先验证现有方案是否已覆盖(Ralph Loop iteration重启=最强compaction, 被误判为"缺失"). 机制修复: 调研产出的每个"建议/差距"在写入findings前必须过苏格拉底三层: ①这个问题在当前框架里真的存在吗(检查现有方案) ②在目标平台上可行吗(Kiro/CC约束) ③收益>维护成本吗. 触发条件: "调研结论输出"本身就是关键决策点, 不只是"设计/方案选择"才触发
## [principle,reform,timid,optimization]
🟡 1. 优化方案分析时因"副作用多""改动大"而退缩到小幅优化(3-9%提升), 回避架构级改革(多进程并行+worktree隔离). 用户纠正: 顶层纲领"Bold reform over timid patches"要求效果为王, 不怕麻烦. 副作用不是回避的理由而是要解决的工程问题. DO: 先定义最优效果目标, 再解决实现中的副作用. DON'T: 因为副作用多就降低目标选凑合方案
## [refactor,capability]
🟡 1. 重构过度聚焦新功能, 差点丢失旧框架核心能力

## [fs_write,kiro,tool,revert,modify]
🔴 1. Kiro的fs_write工具会在两次tool call之间恢复被修改的文件到原始状态. 所有源码修改必须在单个execute_bash调用中完成(Python脚本批量修改), 并在同一调用中git commit持久化. 不要用fs_write修改源码后期望下一个tool call能看到变更
