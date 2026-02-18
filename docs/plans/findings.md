# Findings — TDD Checklist Enforcement

## Pipe vs Process Substitution in Bash Hooks

**Problem:** `echo "$CONTENT" | grep ... | while read` runs the while loop in a subshell. `exit 2` inside the loop only exits the subshell, not the parent script. The hook appears to succeed (exit 0) even when it should block.

**Solution:** Use process substitution: `while read ...; do ... done < <(echo "$CONTENT" | grep ...)`. This runs the loop in the current shell, so `exit 2` propagates correctly.

**Rule:** All hooks that iterate over filtered content and may need to `exit 2` must use process substitution, never pipe-based while loops.

## Live Lock Testing in Hooks

**Problem:** Using background processes (`bash -c 'echo $$ > lock; sleep 5' &`) in test suites causes hangs when the test runner exits before the background process.

**Solution:** Use the current shell's PID (`$$`) as the live lock PID — it's guaranteed alive during test execution. No background processes needed.

## Consolidated Hook Design (enforce-ralph-loop)

**Decision:** Single hook handles both `execute_bash` and `fs_write` via MODE variable, registered twice in default.json with different matchers. This is cleaner than embedding ralph-loop checks in pre-write.sh (separation of concerns).

**Key patterns:**
- `case "$TOOL_NAME" in ... MODE="bash" / MODE="write"` for tool dispatch
- Path-based allowlist via `case "$FILE" in` for fs_write (simpler than regex)
- Strict read-only allowlist + chain rejection for execute_bash (no `&&`, `||`, `;`, `|`, `>`, backticks, `$(`)

## Workspace Hash Isolation for Hook Tests

**Problem:** Integration tests that invoke security hooks directly share the same `/tmp/block-count-<hash>.jsonl` file as live hooks, because both run from the same workspace directory. Counts accumulate across the interactive session and test runs, causing flaky assertions.

**Solution:** Run hook invocations from a `mktemp -d` directory. The `pwd | shasum` in `block-recovery.sh` produces a unique hash, isolating test counts from live session counts. Cleanup via `trap 'rm -rf "$TEST_DIR"' EXIT`.

## Git Stash Self-Revert in ralph-loop.sh

**Problem:** `ralph-loop.sh` runs `git stash push` before each iteration to save dirty state. When testing the script with uncommitted changes to the script itself, the stash reverts those changes mid-execution. The script then runs the old (pre-edit) version.

**Solution:** Always commit changes to `ralph-loop.sh` before running integration tests that invoke it. The `git stash push` inside the script is by design (protects against dirty state during agent runs), so the fix is in the workflow, not the code.

**Rule:** When modifying ralph-loop.sh, commit before testing.

## enforce-ralph-loop Blocks Checklist Verify Commands

**Problem:** Several checklist verify commands are themselves blocked by enforce-ralph-loop.sh:
- `python3 -m pytest tests/ -q` — not in read-only allowlist
- `grep -c '|' docs/INDEX.md` — hook interprets `|` in grep pattern as a pipe character
- `diff CLAUDE.md AGENTS.md` — standalone `diff` not in allowlist (only `git diff` is)

**Impact:** When executing the final checklist items outside ralph-loop, the verify commands can't be run via bash. Must use alternative tools (grep tool, md5 command, fs_read) or run inside ralph-loop.

**Recommendation:** Consider adding `python3 -m pytest`, `diff`, and `bash -c 'test ...'` to the read-only allowlist, or make the pipe detection smarter (distinguish `|` in grep patterns from actual shell pipes).

## pre-write.sh Absolute Path Bug (Kiro Compatibility)

**Problem:** Kiro CLI sends absolute paths in `tool_input.path` (e.g. `/Users/.../CLAUDE.md`), but `gate_instruction_files` in pre-write.sh only matched relative paths (`CLAUDE.md`, `./CLAUDE.md`). This meant the instruction file write protection was silently bypassed when running under Kiro.

**Fix:** Added workspace-relative path normalization immediately after FILE extraction:
```bash
WORKSPACE=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")
case "$FILE" in "$WORKSPACE"/*) FILE="${FILE#$WORKSPACE/}" ;; esac
```

**Impact:** Same pattern already existed in `enforce-ralph-loop.sh`. Any hook that does path-based matching on `tool_input.path`/`tool_input.file_path` must normalize to relative paths first.

**Rule:** All hooks parsing file paths from tool_input must normalize absolute→relative before pattern matching.

## Long-Running Agent Research (2026-02-19)

> Sources: Anthropic "Effective Harnesses for Long-Running Agents" (2025-11-26), Anthropic "Effective Context Engineering for AI Agents" (2025-09-29), Manus context engineering practices, Claude Code Agent Teams/Swarm Mode (2026-02)

### 核心发现

**1. Anthropic 论文的两阶段 Agent 架构**

论文核心创新：Initializer Agent（首次 session 搭建环境）+ Coding Agent（后续 session 增量推进）。

- Initializer Agent 职责：写 feature list（JSON 格式）、写 init.sh、写 progress.txt、做初始 git commit
- Coding Agent 职责：每次 session 先读 progress + git log + 跑基础测试，然后只做一个 feature，完成后 commit + 更新 progress
- 关键发现：JSON 格式的 feature list 比 Markdown 更不容易被 agent 篡改
- 关键发现：不先验证环境就开始新 feature 会让已有 bug 更严重

**2. Context Rot 与 Compaction**

Anthropic context engineering 论文核心观点：context 是有限资源，随 token 增加注意力预算被稀释（n² pairwise relationships）。

- Manus 实践：tool result 有 full/compact 两种表示，旧 result 自动替换为 compact（只保留路径引用）
- Anthropic 平台：context editing 功能自动清除 stale tool call results
- 研究发现：直接移除旧 tool result（不做 LLM summarization）在 observation-heavy 场景下效果等同或更好
- 关键原则："find the smallest possible set of high-signal tokens that maximize the likelihood of desired outcome"

**3. Sub-agent 架构演进 → Agent Teams**

Claude Code 2026 年初推出 Agent Teams（Swarm Mode）：

- 7 个原语：TeamCreate, TaskCreate, TaskUpdate, TaskList, Task(team_name), SendMessage, TeamDelete
- 关键区别：subagent 只能报告回 parent，Agent Teams 成员可以互相直接通信
- 共享 task list（文件系统上的 JSON），自主认领任务
- 最佳实践：plan first（便宜），parallelize second（贵但快）
- 成本模型：每个 teammate 是完整 context window，更多 agent = 更多 token

**4. Manus 的 Context Engineering 三策略**

- Reduce：compact stale results → summarize when compaction 收益递减
- Offload：tool result 存文件系统，用 glob/grep 按需检索；action 推到 sandbox 层（小 tool set + Bash）
- Isolate：sub-agent 主要目的是隔离 context（不是分工）；简单任务只传指令，复杂任务传完整 context

**5. Bitter Lesson 防护**

Manus 的 Peak 警告：agent harness 可能限制模型性能提升。

- 做法：跨模型强度运行 eval，如果更强模型没带来性能提升，说明 harness 在拖后腿
- Claude Code 创始人 Boris Cherny 也受 Bitter Lesson 影响，保持 Claude Code 不 opinionated
- Manus 自 2025-03 发布以来已重构 5 次

### 与现有框架的对照分析

| 论文/行业实践 | 框架现状 | 差距 |
|---|---|---|
| Initializer Agent 首次搭建环境 | Ralph Loop 每次 iteration 用相同 prompt | 🔴 缺少 |
| Tool result compaction | 每次 iteration 新 CLI 实例（天然隔离），但单次内无 compaction | 🔴 缺少 |
| 每次 session 先跑测试验证环境 | build_prompt 没有"先验证环境"指令 | 🟡 缺少 |
| Feature list 用 JSON | Checklist 用 Markdown（已有误判 episode） | 🟡 可优化 |
| Agent 间直接通信（Teams） | Strategy D 是 fire-and-forget | 🟡 可升级 |
| Bitter Lesson 防护 | Hook 约束较刚性，无松弛模式 | 🟢 低优先 |
| 增量推进 + commit + progress | ✅ Ralph Loop + progress.md + findings.md | 已覆盖 |
| Hook 强制执行 | ✅ PreToolUse/PostToolUse/Stop | 领先论文 |
| Circuit breaker | ✅ 3 轮无进展自动停止 | 领先论文 |
| Plan review 多角度审查 | ✅ 4 reviewer 并行 | 领先论文 |
| Knowledge 自进化 | ✅ episodes + self-reflect | 领先论文 |
| Security hooks | ✅ 多层安全拦截 | 领先论文 |

### 优化建议优先级

| 优先级 | 方向 | 预期收益 | 实现难度 |
|---|---|---|---|
| P0 | Tool Result Compaction 指令（改 prompt） | 单次 iteration 内防降智 | 低 |
| P0 | 每次 iteration 先跑测试验证环境（改 prompt） | 防止在坏环境上叠加 bug | 低 |
| P1 | Initializer Agent 模式（改 ralph_loop.py） | 第一个 iteration 更高效 | 中 |
| P1 | Agent Teams 支持（需 CC 实验特性） | 并行 agent 间通信 | 中 |
| P2 | Checklist JSON 分离（改 plan.py + hooks） | 消除 Markdown 解析误判 | 中 |
| P2 | Bitter Lesson 防护（加环境变量） | 框架不限制模型进步 | 低 |
