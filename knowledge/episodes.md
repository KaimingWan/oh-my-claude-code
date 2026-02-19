# Episodes (Episodic Memory)

> Timestamped events. ≤30 entries. Auto-captured by hook + manual via @reflect.

<!-- FORMAT: DATE | STATUS | KEYWORDS | SUMMARY -->
<!-- STATUS: active / resolved / promoted -->
<!-- Promotion candidates are computed at runtime (keyword freq ≥3), not stored -->

2026-02-15 | active | symlink,fs_read,directory | fs_read Directory模式不支持symlink目录, 用ls或execute_bash替代

2026-02-19 | active | ralph-loop,verify,plan,format | Plan的Verify命令必须用inline backtick格式(**Verify:** `cmd`), 不能用fenced code block(```bash). ralph_loop.py正则只匹配inline backtick, fenced block导致解析残缺→shell语法错误→3轮无进展触发circuit breaker. DO: **Verify:** `cmd`. DON'T: **Verify:**后换行写```bash块


2026-02-19 | resolved | ralph-loop,check-off,parallel,worktree | check_off()假设Task:Checklist=1:1映射, 实际可能1:N(6 tasks, 15 items). 修复: verify_and_check_all()遍历所有unchecked items运行其verify command, 通过的直接勾选, 不依赖task-to-item位置映射

2026-02-19 | resolved | git,active,staged,commit,guard | git commit时staged的.active文件可能包含旧plan路径(stale staged change), 导致已关闭的plan被意外重新激活. 修复: enforce-ralph-loop.sh加early guard, commit前检查staged .active是否与HEAD不同

2026-02-20 | resolved | test,worktree,merge,pollution,cwd | test_parallel_batch_creates_worktrees在主repo里运行ralph_loop.py→创建worktree分支→merge commit污染主repo history. 同时git_repo fixture的os.chdir(tmp_path)未恢复导致cwd污染. 修复: tests/conftest.py autouse fixture同时guard cwd和HEAD, 测试后reset --hard回原始HEAD+删stale分支. 教训: 测试如果在真实repo里运行subprocess, 必须guard所有副作用(HEAD/branches/worktrees), 不只是cwd

2026-02-20 | resolved | stale-process,kiro-cli,background,merge | 旧kiro-cli session进程(含ralph loop worker)在后台持续运行数天, 不断做git merge ralph-worker-w2-i1. kill stale进程后问题消失. 教训: 长时间运行的agent session退出后检查是否有残留进程(ps aux | grep kiro-cli)
