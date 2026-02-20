# Episodes (Episodic Memory)

> Timestamped events. ≤30 entries. Auto-captured by hook + manual via @reflect.

<!-- FORMAT: DATE | STATUS | KEYWORDS | SUMMARY -->
<!-- STATUS: active / resolved / promoted -->
<!-- Promotion candidates are computed at runtime (keyword freq ≥3), not stored -->

2026-02-15 | active | symlink,fs_read,directory | fs_read Directory模式不支持symlink目录, 用ls或execute_bash替代

2026-02-19 | active | ralph-loop,verify,plan,format | Plan的Verify命令必须用inline backtick格式(**Verify:** `cmd`), 不能用fenced code block(```bash). ralph_loop.py正则只匹配inline backtick, fenced block导致解析残缺→shell语法错误→3轮无进展触发circuit breaker. DO: **Verify:** `cmd`. DON'T: **Verify:**后换行写```bash块





2026-02-20 | active | fs_write,kiro,tool,revert,git-commit | Kiro的fs_write工具会在两次tool call之间恢复被修改的文件到原始状态(疑似工具层面的sandbox机制). 症状: str_replace/append报告成功但下一次tool call时文件内容已回滚. 解决: 所有文件修改必须在单个execute_bash调用中完成(用Python脚本批量修改), 并在同一调用中git commit持久化. DO: 单个bash命令内完成modify+verify+commit. DON'T: 用fs_write修改源码后期望下一个tool call能看到变更

2026-02-20 | active | debugging,lsp,research,skill,industry | Agent debugging能力弱的根因不是"最佳实践流程"不够, 而是debugging skill只教哲学不教工具. 行业调研发现: ①SOTA agent(Refact.ai 70.4% SWE-bench)全部用语义导航工具(search_symbol_definition/usages), 不靠grep ②LSP findReferences返回23精确调用点 vs grep返回500+噪音(token省4x) ③Refact.ai强制debug_script()子agent至少调1次, 不封装成专用工具时模型会跳过调试直接改代码 ④SWE-Exp论文: 检索1条历史经验效果最好, 多了反而降性能 ⑤lsp-tools三铁律: 不goToDefinition不改代码/不findReferences不重构/不getDiagnostics不声称正确. 方案方向: 重写debugging skill嵌入LSP工具链+强制诊断证据+工具决策矩阵+episodes检索+修改前后diagnostics对比
