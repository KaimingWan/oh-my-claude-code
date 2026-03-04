# OV 自动落库与召回强化

**Goal:** 确保 knowledge 文件变更通过任何路径（fs_write、execute_bash、外部编辑、git pull）都自动同步到 OV，且召回失败时有明确告警而非静默降级。
**Non-Goals:** 不改 OV daemon 本身（ov-daemon.py）；不改 OV 数据格式；不新增 OV 命令。
**Architecture:** 三层加固——(1) session-init 冷启动时检查 daemon + 增量同步 knowledge 文件到 OV；(2) post-bash hook 检测 execute_bash 后 knowledge 文件变更并同步；(3) context-enrichment Layer 4 OV 失败时 emit 告警。
**Tech Stack:** Bash (hooks), Python3 (ov-daemon 启动检测)
**Work Dir:** `.`

## Review

**Round 1 (4 reviewers):**
- Goal Alignment: APPROVE
- Verify Correctness: REQUEST CHANGES (false positive — rejected)
- Completeness: REQUEST CHANGES → fixed (stronger Task 2 verify, added silent-failure test)
- Technical Feasibility: subagent failed

**Round 2 (2 reviewers, fixed angles only):**
- Goal Alignment: APPROVE
- Verify Correctness: APPROVE

**Final Verdict: APPROVE**

## Tasks

### Task 1: session-init OV 冷启动 + 增量同步

**Files:**
- Modify: `hooks/feedback/session-init.sh`
- Lib: `hooks/_lib/ov-init.sh` (已有，直接 source)

**What to implement:**

在 session-init.sh 末尾（`touch "$LESSONS_FLAG"` 之前）加入 OV 初始化段：

1. source ov-init.sh，调用 ov_init
2. 如果 OV daemon 未运行（socket 不存在），尝试后台启动 `python3 scripts/ov-daemon.py &`，等待最多 3 秒 socket 出现
3. OV 可用后，遍历 `knowledge/*.md`，对每个文件调用 `ov_add` 做增量同步
4. 如果 OV 始终不可用（overlay 未配置或 daemon 启动失败），emit 一行告警

**Verify:** `grep -q 'ov_add' hooks/feedback/session-init.sh && grep -q 'ov-daemon' hooks/feedback/session-init.sh`

### Task 2: post-bash hook 检测 knowledge 文件变更

**Files:**
- Modify: `hooks/feedback/post-bash.sh`
- Lib: `hooks/_lib/ov-init.sh` (已有)

**What to implement:**

在 post-bash.sh 的 verify log 写入之后，增加 OV 同步段：

1. 检查命令字符串是否包含 `knowledge/` 路径引用，如果包含则对匹配的 .md 文件调用 `ov_add`
2. 静默失败（OV 不可用时不阻塞 bash 执行）

**Verify:** `grep -q 'ov_add' hooks/feedback/post-bash.sh`

### Task 3: context-enrichment OV 召回失败告警

**Files:**
- Modify: `hooks/feedback/context-enrichment.sh`

**What to implement:**

修改 Layer 4 段：当 overlay 配置了 openviking 但 `ov_init` 失败时，emit 告警行 `⚠️ OV unavailable — knowledge semantic recall degraded. Run: python3 scripts/ov-daemon.py &` 而非静默跳过。

**Verify:** `grep -q 'OV unavailable' hooks/feedback/context-enrichment.sh`

### Task 4: 测试

**Files:**
- Modify: `tests/test_ov_capture.py` (增加 post-bash OV 同步测试)
- Modify: `tests/test_ov_recall.py` (增加 OV 不可用告警测试)

**What to implement:**

1. `test_post_bash_indexes_knowledge_changes`: mock OV socket，模拟 execute_bash 写入 knowledge 文件的 hook input，验证 ov_add 被调用
2. `test_post_bash_silent_when_ov_down`: OV 不可用时 post-bash 仍正常退出（exit 0），不报错
3. `test_enrichment_warns_when_ov_down`: overlay 配置了 openviking 但 socket 不存在，验证 stdout 包含 `⚠️ OV unavailable`

**Verify:** `python3 -m pytest tests/test_ov_capture.py tests/test_ov_recall.py -v`

## Checklist

- [x] session-init 启动时自动启动 OV daemon（如未运行） | `bash -c 'source hooks/_lib/ov-init.sh && type ov_init' && grep -q 'ov-daemon' hooks/feedback/session-init.sh`
- [x] session-init 增量同步 knowledge/*.md 到 OV | `grep -q 'ov_add' hooks/feedback/session-init.sh`
- [x] post-bash 检测 knowledge 文件变更并同步 OV | `grep -q 'knowledge/' hooks/feedback/post-bash.sh && grep -A3 'knowledge/' hooks/feedback/post-bash.sh | grep -q 'ov_add'`
- [x] context-enrichment OV 失败时 emit 告警 | `grep -q 'OV unavailable' hooks/feedback/context-enrichment.sh`
- [x] 所有 hook 语法正确 | `bash -n hooks/feedback/session-init.sh && bash -n hooks/feedback/post-bash.sh && bash -n hooks/feedback/context-enrichment.sh`
- [x] 新增测试通过 | `python3 -m pytest tests/test_ov_capture.py tests/test_ov_recall.py -v`
- [x] 不使用 macOS 不存在的 timeout 命令 | `! grep -rn '\btimeout\b' hooks/feedback/session-init.sh hooks/feedback/post-bash.sh hooks/feedback/context-enrichment.sh`

## Errors

| Error | Task | Attempt | Resolution |
|-------|------|---------|------------|
