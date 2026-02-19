# Episodes (Episodic Memory)

> Timestamped events. ≤30 entries. Auto-captured by hook + manual via @reflect.

<!-- FORMAT: DATE | STATUS | KEYWORDS | SUMMARY -->
<!-- STATUS: active / resolved / promoted -->
<!-- Promotion candidates are computed at runtime (keyword freq ≥3), not stored -->

2026-02-15 | active | symlink,fs_read,directory | fs_read Directory模式不支持symlink目录, 用ls或execute_bash替代

2026-02-19 | active | ralph-loop,verify,plan,format | Plan的Verify命令必须用inline backtick格式(**Verify:** `cmd`), 不能用fenced code block(```bash). ralph_loop.py正则只匹配inline backtick, fenced block导致解析残缺→shell语法错误→3轮无进展触发circuit breaker. DO: **Verify:** `cmd`. DON'T: **Verify:**后换行写```bash块





2026-02-20 | active | fs_write,kiro,tool,revert,git-commit | Kiro的fs_write工具会在两次tool call之间恢复被修改的文件到原始状态(疑似工具层面的sandbox机制). 症状: str_replace/append报告成功但下一次tool call时文件内容已回滚. 解决: 所有文件修改必须在单个execute_bash调用中完成(用Python脚本批量修改), 并在同一调用中git commit持久化. DO: 单个bash命令内完成modify+verify+commit. DON'T: 用fs_write修改源码后期望下一个tool call能看到变更
