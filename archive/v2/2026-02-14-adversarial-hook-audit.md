# Plan: 框架承诺兑现审计 — 覆盖度 + 有效性

## Goal

两个维度确保框架承诺的能力真正兑现：
1. **覆盖度审计**：AGENTS.md 的每条承诺是否有 hook 强制？（找"承诺了但没 hook"的缺口）
2. **有效性审计**：已有的 hook 能否真正拦住？（找"有 hook 但能绕过"的漏洞）

用户核心痛点：同一会话中 3 次发现"无 hook = agent 跳过"的模式。必须系统性消灭这类缺口。

## Decisions

| # | 决策 | 原因 | 状态 |
|---|------|------|------|
| 1 | ~~只做红队绕过测试~~ | reviewer Round 3 指出：红队测试找不到"根本没有 hook"的缺口，这才是用户核心痛点 | ❌ 废弃 |
| 2 | 先做 Promise-to-Hook 覆盖度映射，再做红队绕过测试 | 覆盖度缺口是核心问题，红队是补充 | ✅ 采纳 |
| 3 | 覆盖度审计由主 agent 做（需要读 AGENTS.md + 所有 hook + 配置） | 需要全局视角，subagent 工具受限（无 code 工具） | ✅ 采纳 |
| 4 | 有效性审计用 subagent 并行（每域一个） | 各 hook 独立，无共享状态 | ✅ 采纳 |
| 5 | 测试方法：`echo JSON \| bash hook.sh` | judgment-only 测试，安全 | ✅ 保留 |

## Steps

### Phase 1: 覆盖度审计（主 agent，串行）

逐条对照 AGENTS.md 的每个承诺，映射到 hook：

```
AGENTS.md 承诺 → 对应 hook → 强制级别（硬阻断/软提醒/无）→ 缺口判定
```

输出：`docs/audit/promise-coverage.md` — 承诺覆盖度矩阵

对每个缺口决策：
- A) 新增 hook 强制（可编码的约束）
- B) 强化软提醒措辞（不可编码但可优化）
- C) 接受为软约束（标注"依赖 agent 自觉"）

### Phase 2: 有效性审计（4 subagent 并行）

对 Phase 1 中标记为"有 hook"的承诺，红队测试 hook 是否真能拦住：

| Subagent | 域 | 测试的 Hook | 预置攻击向量 |
|----------|-----|-----------|------------|
| S1: Security | 安全拦截 | block-dangerous-commands, block-secrets, block-sed-json, scan-skill-injection | env/bash -c/base64/hex 转义/绝对路径/command 前缀/参数拆分/进程替换 |
| S2: Quality | 质量门禁 | enforce-skill-chain, auto-test, verify-completion | 旧 plan 绕过/非源文件绕过/.skip-plan 滥用/debounce 窗口利用/空 Review 段落 |
| S3: Context | 上下文注入 | context-enrichment | 纠正不触发/复杂任务不触发/LLM 异常格式/关键词遗漏 |
| S4: Cross-hook | 攻击链 + 配置 | 多 hook 组合 + settings.json/default.json matcher | HOOKS_DRY_RUN=true/.skip-plan→写代码/分步 Edit 注入/matcher 遗漏工具名 |

### Phase 3: 修复（主 agent，串行）

汇总 Phase 1 + Phase 2 的所有发现，统一修复。

## 输出格式

### Phase 1 输出：docs/audit/promise-coverage.md

```markdown
# 承诺覆盖度矩阵

| AGENTS.md 段落 | 具体承诺 | Hook | 强制级别 | 缺口 | 决策 |
|---------------|---------|------|---------|------|------|
| Verification First | 完成前必须有验证证据 | verify-completion (Stop) | 软提醒(Kiro)/硬阻断(CC) | Kiro 不能阻断 | B: 接受平台限制 |
| Workflow | 先调研再计划再编码 | context-enrichment + enforce-skill-chain | 软提醒+硬阻断 | 调研步骤无强制 | A: 考虑新增 hook |
| ... | ... | ... | ... | ... | ... |
```

### Phase 2 输出：docs/audit/hook-bypass-report.md

```markdown
# Hook 绕过测试报告

## S1: Security

| # | Hook | 绕过方法 | Payload | exit code | 结果 |
|---|------|---------|---------|-----------|------|
| 1 | block-dangerous-commands | bash -c 间接执行 | `echo '{"tool_name":"execute_bash","tool_input":{"command":"bash -c \"rm -rf /\""}}' \| bash hook.sh` | 0 | 🔴 绕过 |
```

## Review

### Reviewer Round 1-2 (2026-02-14)
见旧版 plan 的 review 记录。核心采纳：具体攻击向量、攻击链测试、hook 注册审计。

### Reviewer Round 3 (2026-02-14) — 关键转折
指出旧 plan 解决的是错误问题。用户核心痛点是"承诺了但没有 hook"，不是"有 hook 但能绕过"。

**采纳：重构 plan 为两阶段——先覆盖度映射（找缺口），再红队测试（验有效性）。**

这直接回答了用户的问题："以后如何杜绝约束写了但实际没法奏效的情况"——答案是先有一张完整的覆盖度矩阵，让每个承诺的强制状态可见。
