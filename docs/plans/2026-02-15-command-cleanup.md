# Command Cleanup — Sync, Trim, Auto-trigger

**Goal:** 删除无用命令、同步 README 命令表、通过 context-enrichment 自动触发 debugging/research skill。
**Architecture:** 删 commands/debug.md，改 README/AGENTS.md 命令表，rules.md 加 debugging section，context-enrichment.sh 加 research 关键词检测。
**Tech Stack:** Markdown, Bash (hook)

## Tasks

### Task 1: 删除 @debug 命令

**Files:**
- Delete: `commands/debug.md`

**Verify:**
```bash
! test -f commands/debug.md
```

### Task 2: Debugging 核心原则写入 rules.md

**Files:**
- Modify: `knowledge/rules.md`

在文件末尾追加新 keyword section：

```markdown
## [debugging, bug, error, failure, fix, broken]
1. 修 bug 前必须先复现、定位根因，禁止猜测性修复。NO FIX WITHOUT ROOT CAUSE。
2. 遇到测试失败：先读完整错误信息和堆栈，再行动。
3. 连续修 3 次不成功 → 停下来，重新从复现开始。
```

**Verify:**
```bash
grep -q '## \[debugging' knowledge/rules.md
```

### Task 3: Context-enrichment 加 research 关键词检测

**Files:**
- Modify: `hooks/feedback/context-enrichment.sh`

在 correction detection 的 `fi` 之后（约第 42 行 `touch ... .flag` 之后）、`# 2. Unfinished task resume` 注释之前，插入：

```bash
# Research skill reminder
if echo "$USER_MSG" | grep -qE '(调研|研究一下|查一下|了解一下|对比.*方案)'; then
  echo "🔍 Research detected → read skills/research/SKILL.md for search level strategy (L0→L1→L2)."
elif echo "$USER_MSG" | grep -qiE '(research|investigate|look into|compare.*options|find out)'; then
  echo "🔍 Research detected → read skills/research/SKILL.md for search level strategy (L0→L1→L2)."
fi
```

**Verify:**
```bash
grep -q 'Research detected' hooks/feedback/context-enrichment.sh
```

### Task 4: 更新 AGENTS.md

**Files:**
- Modify: `AGENTS.md`

Skill routing 表中，将：
```
| 调试 | debugging | `@debug` 命令 |
```
改为：
```
| 调试 | debugging | rules.md 自动注入 |
```

**Verify:**
```bash
! grep -q '@debug' AGENTS.md && grep -q 'rules.md 自动注入' AGENTS.md
```

### Task 5: 更新 README 命令表

**Files:**
- Modify: `README.md`

3 处修改：

**Line 27** — L1 Commands 行，改为：
```
| L1 Commands | `@plan` `@execute` `@research` `@review` `@reflect` `@cpu` `@skill` | 100% — user triggers full workflow |
```

**Line 56** — 架构图命令行，改为：
```
│  @plan · @execute · @research · @review · @reflect · @cpu · @skill  │
```

**Lines 86-91** — 命令表格，删除 @debug 行（line 88），新增 @reflect 和 @cpu 行：
```
| `@plan` | brainstorming → write plan (with checklist) → reviewer challenge → fix until APPROVE → user confirm |
| `@execute` | load approved plan → Ralph Loop: bash outer loop checks checklist → fresh Kiro instance per iteration → no stops until all items checked off |
| `@research` | L0 built-in knowledge → L1 web search → L2 deep research → write findings to file |
| `@review` | dispatch reviewer subagent → categorize P0-P3 → cite file:line |
| `@reflect` | manual knowledge capture → extract insight → dedup check → append to episodes.md |
| `@cpu` | commit all changes → push to remote → update README if needed |
| `@skill` | list all skills with descriptions, match user need to closest skill |
```

**Verify:**
```bash
! grep -q '@debug' README.md && grep -q '@reflect' README.md && grep -q '@cpu' README.md
```

## Review

### Round 1 (Completeness, Compatibility, Testability, Clarity)

| Angle | Verdict | Key Finding |
|-------|---------|-------------|
| Completeness | REJECT | Missing content migration verification |
| Compatibility | REJECT | @debug removal is breaking — **dismissed: user explicitly requested this** |
| Testability | REJECT | Minor grep concerns — **dismissed: files exist, syntax valid** |
| Clarity | REJECT | Task 5 README changes not specific enough |

**Fixes applied:**
- Task 5: added exact line numbers and replacement content for all 3 README locations
- Compatibility/Testability REJECTs dismissed with reason (user decision / non-issue)

## Checklist

- [x] commands/debug.md 已删除 | `! test -f commands/debug.md`
- [x] rules.md 有 debugging keyword section | `grep -q '## \[debugging' knowledge/rules.md`
- [x] debugging rules 包含根因原则 | `grep -q 'ROOT CAUSE' knowledge/rules.md`
- [x] context-enrichment 有 research 检测 | `grep -q 'Research detected' hooks/feedback/context-enrichment.sh`
- [x] research 检测覆盖中英文 | `grep -q '调研' hooks/feedback/context-enrichment.sh && grep -qi 'research' hooks/feedback/context-enrichment.sh`
- [x] AGENTS.md 无 @debug 引用 | `! grep -q '@debug' AGENTS.md`
- [x] AGENTS.md debugging 触发方式已更新 | `grep -q 'rules.md 自动注入' AGENTS.md`
- [ ] README 无 @debug | `! grep -q '@debug' README.md`
- [ ] README 有 @reflect | `grep -q '@reflect' README.md`
- [ ] README 有 @cpu | `grep -q '@cpu' README.md`
- [ ] hook 语法正确 | `bash -n hooks/feedback/context-enrichment.sh`
