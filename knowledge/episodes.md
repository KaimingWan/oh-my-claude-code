# Episodes (Episodic Memory)

> Timestamped events. ≤30 entries. Auto-captured by hook + manual via @reflect.

<!-- FORMAT: DATE | STATUS | KEYWORDS | SUMMARY -->
<!-- STATUS: active / resolved / promoted -->
<!-- Promotion candidates are computed at runtime (keyword freq ≥3), not stored -->

2026-02-15 | active | symlink,fs_read,directory | fs_read Directory模式不支持symlink目录, 用ls或execute_bash替代

2026-02-19 | active | ralph-loop,verify,plan,format | Plan的Verify命令必须用inline backtick格式(**Verify:** `cmd`), 不能用fenced code block(```bash). ralph_loop.py正则只匹配inline backtick, fenced block导致解析残缺→shell语法错误→3轮无进展触发circuit breaker. DO: **Verify:** `cmd`. DON'T: **Verify:**后换行写```bash块
