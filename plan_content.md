# Hook 治理：降低误拦截 + 精简输出

**Goal:** enforce-ralph-loop.sh 白名单改黑名单（只拦截修改 plan 跟踪文件的命令），收窄 block-dangerous.sh 和 block-outside-workspace.sh 误报，压缩所有 hook 输出减少上下文污染。
**Non-Goals:** 改变 hook 三分类架构。重写 ralph-loop 核心。新增 hook。改变注册机制。
**Architecture:** (1) enforce-ralph-loop.sh 翻转为黑名单——解析 plan Files: 字段提取受保护文件，只拦截修改这些文件的命令 (2) dangerous/outside-workspace 收窄模式 (3) 所有 hook 输出压缩——block 单行化，feedback 加预算上限+去重
**Tech Stack:** Bash, Python 3 (pytest)

## Tasks

### Task 1: enforce-ralph-loop.sh 黑名单重构

白名单改黑名单。默认放行，只拦截修改 plan 跟踪文件的写操作。

**Files:**
- Modify: `hooks/gate/enforce-ralph-loop.sh`
- Create: `tests/hooks/test-ralph-gate.sh`

**What to implement:**
- 新增 `extract_protected_files()` 函数：解析活跃 plan 的 `**Files:**` 段，提取 Modify/Create 的文件路径（不含 Test/Delete）
- bash 模式：保留 .active 操纵拦截和 ralph-loop/skip 绕过，删除整个白名单逻辑，改为：检查命令是否包含对受保护文件的写操作（redirect `>` 到受保护路径、`sed -i` 受保护路径等）
- fs_write 模式：保留现有 allowlist（plan/knowledge/completion-criteria），新增：如果文件不在受保护列表中则放行
- 保留：stale .active guard、lock file check、brainstorm gate

**Verify:** `bash tests/hooks/test-ralph-gate.sh`

### Task 2: block-dangerous.sh 收窄模式

**Files:**
- Modify: `hooks/security/block-dangerous.sh`
- Modify: `hooks/_lib/patterns.sh`
- Modify: `tests/hooks/verify-block-dangerous.sh`

**What to implement:**
- patterns.sh: `git branch -[dD]` 改为只拦强制删除大写 D；移除 pkill 和 killall；`find.*-delete` 改为只拦 `find /` 开头
- block-dangerous.sh: kill -9 保留

**Verify:** `bash tests/hooks/verify-block-dangerous.sh`

### Task 3: block-outside-workspace.sh 放行 /tmp/

**Files:**
- Modify: `hooks/security/block-outside-workspace.sh`
- Create: `tests/hooks/test-outside-workspace.sh`

**What to implement:**
- 从 OUTSIDE_WRITE_PATTERNS 移除 `/tmp/` 相关的 redirect 模式
- cp/mv/tee/tar 模式当前已不含 /tmp/，确认即可

**Verify:** `bash tests/hooks/test-outside-workspace.sh`

### Task 4: block 消息单行化

**Files:**
- Modify: `hooks/_lib/block-recovery.sh`
- Modify: `hooks/_lib/common.sh`
- Modify: `hooks/security/block-dangerous.sh`
- Modify: `hooks/security/block-secrets.sh`
- Modify: `hooks/security/block-sed-json.sh`
- Modify: `hooks/security/block-outside-workspace.sh`
- Create: `tests/hooks/test-block-output.sh`

**What to implement:**
- common.sh hook_block(): 输出改为单行
- block-recovery.sh hook_block_with_recovery(): 压缩为单行格式
- 各 security hook 调用处：传单行 reason + 单行 alternative

**Verify:** `bash tests/hooks/test-block-output.sh`

### Task 5: context-enrichment.sh 输出预算+去重

**Files:**
- Modify: `hooks/feedback/context-enrichment.sh`
- Create: `tests/hooks/test-context-budget.sh`

**What to implement:**
- 输出缓冲：收集所有输出行，末尾截断到 max 8 行
- 去重：hash 输出存临时文件，60s 内同 hash 只输出 1 行
- 规则注入上限 3 条

**Verify:** `bash tests/hooks/test-context-budget.sh`

### Task 6: feedback hook 输出精简

**Files:**
- Modify: `hooks/gate/pre-write.sh`
- Modify: `hooks/feedback/post-write.sh`
- Modify: `hooks/feedback/verify-completion.sh`
- Create: `tests/hooks/test-feedback-output.sh`

**What to implement:**
- pre-write.sh inject_plan_context(): 始终 1 行摘要，删除每 5 次 dump 全 checklist 逻辑
- post-write.sh run_test(): 失败输出 tail -3（原 tail -10）
- verify-completion.sh: 只输出摘要不逐条列出

**Verify:** `bash tests/hooks/test-feedback-output.sh`

### Task 7: 回归测试 + 文档更新

**Files:**
- Modify: `docs/designs/2026-02-18-hook-architecture.md`

**What to implement:**
- 跑 test-kiro-compat.sh 确认回归
- 更新 hook-architecture.md
- validate configs

**Verify:** `bash tests/hooks/test-kiro-compat.sh && python3 scripts/generate_configs.py --validate`

## Checklist

- [ ] enforce-ralph-loop 黑名单模式 | `bash tests/hooks/test-ralph-gate.sh`
- [ ] block-dangerous 收窄 | `bash tests/hooks/verify-block-dangerous.sh`
- [ ] block-outside-workspace 放行 /tmp/ | `bash tests/hooks/test-outside-workspace.sh`
- [ ] block 输出 ≤3 行 | `bash tests/hooks/test-block-output.sh`
- [ ] context-enrichment 输出 ≤8 行 | `bash tests/hooks/test-context-budget.sh`
- [ ] feedback 输出精简 | `bash tests/hooks/test-feedback-output.sh`
- [ ] 回归测试通过 | `bash tests/hooks/test-kiro-compat.sh`
- [ ] config 验证通过 | `python3 scripts/generate_configs.py --validate`

## Review

## Errors

| Error | Task | Attempt | Resolution |
|-------|------|---------|------------|

## Findings

