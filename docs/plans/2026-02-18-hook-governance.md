# Hook Governance — 审计、优化、固化

**Goal:** 全面审计现有 hook 体系，修复不一致和冗余，产出 Hook Architecture Design Doc（含扩展性设计）并用代码层机制固化设计，防止后续迭代破坏，同时保证新 hook 的接入有清晰流程。

**Non-Goals:**
- 不新增 hook 功能（如 LLM eval Stop hook、auto-approve 等）
- 不重构 pre-write.sh 的合并策略（当前合并是有意设计，减少 hook 调用次数）
- 不改变 security/gate/feedback 三分类体系

**Architecture:** 三层治理：(1) enforcement.md 升级为完整的 Hook Architecture Doc，包含分类原则、命名规范、职责边界 (2) generate_configs.py 增加一致性校验，确保生成的 config 与 architecture doc 一致 (3) pre-write gate 增加对 hooks/ 目录修改的保护，要求同步更新 architecture doc。

**Tech Stack:** Bash (hooks), Python (generator/validator), Markdown (architecture doc)

## Audit Findings

### F1: 注册表 drift — enforcement.md 缺失 2 个 hook
`enforce-ralph-loop.sh` 和 `require-regression.sh` 在 generate_configs.py 和 Kiro agent JSON 中注册，但 enforcement.md 没有记录。enforcement.md 作为"单一事实来源"不完整。

### F2: 注册表 drift — settings.json 缺失 2 个 hook
`enforce-ralph-loop.sh` 和 `require-regression.sh` 在 Kiro agent JSON 中注册，但 `.claude/settings.json` 没有。CC 用户不会触发这两个 gate。

### F3: llm-eval.sh 是死代码
`_lib/llm-eval.sh` 存在但没有任何 hook 脚本 source 它。v2 design 规划了 LLM eval 的 Stop hook，但从未接入。50 行死代码。

### F4: pre-write.sh Phase 编号混乱
Phase 顺序是 0 → 1 → 2 → 3 → 1.5a0 → 1.5a → 1.5b。执行顺序和编号不一致（Phase 1.5 系列在 Phase 2/3 之后定义，但在 Phase 2 之前执行）。不影响功能但降低可读性。

### F5: auto-capture.sh 和 kb-health-report.sh 是"影子 hook"
这两个脚本不在 settings.json 或 agent JSON 中注册，而是被其他 hook 内部调用（correction-detect → auto-capture, verify-completion → kb-health-report）。enforcement.md 没有记录这种调用关系。

### F6: session-init.sh 职责过重
73 行，承担 5 个职责：episode cleanup、rules injection、promotion reminder、delegation reminder、KB health report。其中 delegation reminder 是硬编码的一行 echo，每次 session 都输出，价值存疑。

### F7: block-outside-workspace.sh 在每个 agent 中注册了两次
default.json、executor.json、pilot.json、researcher.json、reviewer.json 中，block-outside-workspace.sh 都出现两次（一次 matcher=execute_bash，一次 matcher=fs_write）。这是正确的（不同事件），但 enforcement.md 只记录了一条。

### F8: 三分类体系边界模糊
- `gate/` = 阻断（exit 2），但 `pre-write.sh` 的 `inject_plan_context` 是 advisory（不阻断）
- `feedback/` = 不阻断，但 `post-write.sh` 的 `run_test` 返回 exit 1（PostToolUse 的 exit 1 行为未明确）
- 分类原则没有文档化

### F9: Determinism Layers 表不完整
enforcement.md 的 Determinism Layers 表只有 3 层（Commands/Gate/Feedback），缺少 L0（security hooks，也是 100% hard block）。security 和 gate 都是 exit 2 阻断，但被分到不同层级。

### F10: 测试覆盖不均匀
有测试的：block-dangerous、block-sed-json、instruction-guard（brainstorm-gate + write-protection）、block-recovery、context-enrichment split、kiro-compat
无测试的：block-secrets、block-outside-workspace、enforce-ralph-loop、require-regression、session-init、correction-detect、auto-capture、kb-health-report、verify-completion、post-write、post-bash

## Tasks

### Task 1: 修复注册表 drift + 清理死代码

**Files:**
- Modify: `hooks/_lib/llm-eval.sh` → 移到 `.trash/`
- Modify: `.kiro/rules/enforcement.md`

**Step 1: 移除死代码 llm-eval.sh**
```bash
mv hooks/_lib/llm-eval.sh .trash/llm-eval.sh
```

**Step 2: 重写 enforcement.md 为完整注册表**
更新 enforcement.md，补全所有 15 个 hook（含 2 个影子 hook），标注调用关系和注册状态。

**Verify:**
```bash
# 验证 llm-eval.sh 已移除
test ! -f hooks/_lib/llm-eval.sh
```

### Task 2: 修复 settings.json drift

**Files:**
- Modify: `scripts/generate_configs.py`

**Step 1: 确认 generate_configs.py 是否已包含 enforce-ralph-loop 和 require-regression 的 CC 版本**
检查 generate_configs.py 的 CC settings.json 生成逻辑，补全缺失的 hook 注册。

**Step 2: 重新生成 configs**
```bash
python3 scripts/generate_configs.py
```

**Verify:**
```bash
# 验证 settings.json 包含 enforce-ralph-loop
jq -r '.. | .command? // empty' .claude/settings.json | grep -q 'enforce-ralph-loop'
```

### Task 3: 修复 pre-write.sh Phase 编号

**Files:**
- Modify: `hooks/gate/pre-write.sh`

**Step 1: 重新编号 Phase**
按实际执行顺序重新编号：
- Phase 0: Instruction File Write Protection（不变）
- Phase 1: Workflow Gate（不变）
- Phase 2: Brainstorming Gate（原 1.5a0）
- Phase 3: Plan Structure Rubric（原 1.5a）
- Phase 4: Checklist Check-off Gate（原 1.5b）
- Phase 5: Injection & Secret Scan（原 2）
- Phase 6: Plan Context Injection（原 3，advisory）

**Verify:**
```bash
# 验证 Phase 编号连续且递增
grep -E '^# Phase [0-9]' hooks/gate/pre-write.sh | awk '{print $3}' | sort -n -c 2>&1; echo "exit: $?"
```

### Task 4: 清理 session-init.sh 低价值输出

**Files:**
- Modify: `hooks/feedback/session-init.sh`

**Step 1: 移除硬编码 delegation reminder**
删除 `echo "⚡ Delegation: >3 independent tasks → use subagent per task. Never delegate code/grep/web_search tasks."` 这行。这是每次 session 都输出的噪音，subagent rules 已经在 `.claude/rules/subagent.md` 中覆盖。

**Verify:**
```bash
# 验证 delegation reminder 已移除
! grep -q 'Delegation:' hooks/feedback/session-init.sh
```

### Task 5: 产出 Hook Architecture Design Doc

**Files:**
- Create: `docs/designs/2026-02-18-hook-architecture.md`
- Modify: `docs/INDEX.md`

**Step 1: 写 Hook Architecture Design Doc**
内容包含：
1. **设计原则** — 三分类体系（security/gate/feedback）的定义和边界
2. **命名规范** — 文件命名、函数命名、Phase 编号规则
3. **Hook 全景注册表** — 所有 hook 的事件、类型、职责、调用关系、注册位置
4. **共享库契约** — `_lib/` 中每个文件的 API 和使用规则
5. **影子 hook 规则** — 被其他 hook 内部调用的脚本的管理规范
6. **新增/修改/废弃流程** — 改 hook 的标准流程
7. **Config 生成规则** — generate_configs.py 是唯一 config 来源，禁止手动编辑
8. **扩展性设计** — 包含：
   - **分类决策树** — 新 hook 应该放 security/ 还是 gate/ 还是 feedback/？决策流程：
     ```
     新 hook 需求
       ├── 必须阻断危险操作？ → security/（exit 2, 无条件拦截）
       ├── 必须阻断不合规流程？ → gate/（exit 2, 可 bypass）
       └── 提供反馈/注入上下文？ → feedback/（exit 0, advisory）
     ```
   - **新增 hook 标准流程 checklist** — 从需求到落地的完整步骤：
     1. 确定分类（用决策树）
     2. 写脚本到 `hooks/<category>/`，source `_lib/common.sh`
     3. 更新 enforcement.md 注册表
     4. 更新 generate_configs.py（添加到对应 agent 的 hook 列表）
     5. 运行 `python3 scripts/generate_configs.py` 重新生成 config
     6. 运行 `python3 scripts/generate_configs.py --validate` 确认一致性
     7. 写测试到 `tests/hooks/`
   - **_lib/ 共享库扩展规则** — 新增共享函数的规范（函数签名、文档、向后兼容）
   - **影子 hook 接入规范** — 何时允许 hook 内部调用另一个脚本，如何在注册表中标注
   - **事件扩展点** — 当前覆盖的 4 个事件（PreToolUse/PostToolUse/UserPromptSubmit/Stop）+ 预留的扩展事件（如 Kiro 未来支持 agentSpawn 等新事件时的接入方式）
   - **废弃 hook 标准流程** — hook 废弃/删除的步骤：
     1. 在 enforcement.md 中标记 `deprecated`，注明原因和替代方案
     2. 从 generate_configs.py 中移除注册（config 不再包含该 hook）
     3. 运行 `python3 scripts/generate_configs.py` 重新生成 config
     4. 脚本移到 `.trash/`（保留可恢复），不直接删除
     5. 下一个 major 版本时清理 `.trash/` 中的废弃脚本
   - **Source of Truth 关系** — 明确 enforcement.md（文档）与 generate_configs.py（代码）的主从关系：
     - enforcement.md 是**设计层 source of truth**（分类原则、职责边界、调用关系、扩展规则）
     - generate_configs.py 是**配置层 source of truth**（哪个 hook 注册到哪个 agent 的哪个事件）
     - `--validate` 校验两者一致性：enforcement.md 中注册的 hook 必须在 generator 中有对应配置，反之亦然
     - 两者不一致时，以 enforcement.md 为准（人工设计意图优先），修复 generator

**Step 2: 更新 docs/INDEX.md**
添加 Hook Architecture Doc 的链接。

**Verify:**
```bash
# 验证 architecture doc 存在且包含关键 section（含扩展性）
test -f docs/designs/2026-02-18-hook-architecture.md && \
grep -q '## Design Principles' docs/designs/2026-02-18-hook-architecture.md && \
grep -q '## Hook Registry' docs/designs/2026-02-18-hook-architecture.md && \
grep -q '## Lifecycle' docs/designs/2026-02-18-hook-architecture.md && \
grep -q '## Extensibility' docs/designs/2026-02-18-hook-architecture.md
```

### Task 6: 代码层固化 — pre-write advisory + generate_configs validate 强制

**Files:**
- Modify: `hooks/gate/pre-write.sh`

**Step 1: 在 gate_instruction_files 中增加 hooks/ 目录 advisory 提醒**
修改 `gate_instruction_files()` 函数，增加对 `hooks/` 目录下文件的写入提醒（不阻断）。修改 hook 脚本时，输出 advisory 提醒需要同步更新 enforcement.md 和 generate_configs.py。

逻辑：
```
if FILE matches hooks/**/*.sh:
  echo "⚠️ Hook file modified. Remember to update enforcement.md and run generate_configs.py --validate" >&2
  # 不 exit 2 — 真正的强制在 Task 7 的 --validate 中
```

~~原方案（/tmp 标记文件检查 enforcement.md 是否被修改）已废弃。原因：agent 可以先随便改一行 enforcement.md 触发标记再改 hook，绕过检查。改为 advisory 提醒 + generate_configs.py validate 双层设计：写时提醒（轻量），生成 config 时强制校验（不可绕过）。~~

**Verify:**
```bash
# 验证 hooks/ 目录修改时有 advisory 提醒
echo '{"tool_name":"fs_write","tool_input":{"path":"hooks/security/block-dangerous.sh","file_text":"test","command":"str_replace"}}' | bash hooks/gate/pre-write.sh 2>&1 | grep -q 'Hook file modified'
```

### Task 7: 代码层固化 — generate_configs.py 增加一致性校验

**Files:**
- Modify: `scripts/generate_configs.py`

**Step 1: 增加 validate 子命令**
在 generate_configs.py 中增加 `--validate` 模式：
- 扫描 `hooks/` 目录下所有 `.sh` 文件（排除 `_lib/`）
- 对比 enforcement.md 的注册表
- 报告：未注册的 hook 脚本、注册了但文件不存在的条目
- 非零 exit code 表示不一致

**Step 2: 在生成 config 时自动运行校验**
每次 `python3 scripts/generate_configs.py` 生成 config 前，先运行一致性校验。不一致则拒绝生成。

**Verify:**
```bash
# 验证 validate 模式可用且当前状态一致
python3 scripts/generate_configs.py --validate
```

### Task 8: 修复 reviewer 质量 — reviewer-prompt.md 增加 show-your-work 要求

**Files:**
- Modify: `agents/reviewer-prompt.md`

**Step 1: 在 Output Structure 中增加 Evidence of Analysis 要求**
在 reviewer-prompt.md 的 `## Output Structure` 中，在 Findings 之前增加 `**Analysis trace:**` 段，要求 reviewer 展示分析过程而不只是结论。

具体增加的规则：
```markdown
## Output Quality Rules

1. **Show your work** — Every finding must include the analysis trace that led to it. 
   "APPROVE — all looks good" without listing what you checked = rubber stamp = violation.
2. **Per-item analysis for Verify Correctness** — Each verify command must have:
   - What it confirms
   - Exit code trace for correct implementation (show intermediate steps, not just "exit 0")
   - Exit code trace for broken implementation
   - Verdict: sound / false-positive / false-negative
   Skipping rows or writing "all sound" without per-row traces = review REJECTED.
3. **Scope check before every finding** — Before writing a finding, re-read the plan's 
   Non-Goals. If your finding addresses a Non-Goal, discard it silently.
4. **Fill the template** — When the dispatch query includes a table template, you MUST 
   copy it and fill every cell. Do not summarize, do not skip rows, do not replace the 
   table with prose. The template IS the minimum acceptable output.
```

**Step 2: 强化 "What I checked" section**
将 Output Structure 中的 `**What I checked and found no issues:**` 改为必填，且要求至少列出 3 个具体检查点（不是泛泛的"checked code quality"）。

**Verify:**
```bash
# 验证 reviewer-prompt.md 包含 show-your-work 规则
grep -q 'Show your work' agents/reviewer-prompt.md && grep -q 'Per-item analysis' agents/reviewer-prompt.md
```

### Task 9: 修复 reviewer 质量 — planning skill angle descriptions 增加 output format 要求

**Files:**
- Modify: `skills/planning/SKILL.md`

**Step 1: 给 Verify Correctness angle 增加 required output format**
在 planning skill 的 Fixed angles 表中，Verify Correctness 的 Mission 改为预填表格模板 + 填空式要求：
```
For each checklist verify command, you MUST copy this table and fill in EVERY cell:

| # | Verify command | Confirms what | Exit code (correct impl) | Exit code (broken impl) | Sound? |
|---|---------------|---------------|--------------------------|--------------------------|--------|
| 1 | [copy from plan] | [fill] | [trace: ... → exit ?] | [trace: ... → exit ?] | [Y/N + reason] |
| 2 | ... | ... | ... | ... | ... |

Rules:
- EVERY row must show the shell execution trace, not just "exit 0" — show the intermediate steps
- If you skip a row or write "all sound" without per-row traces, your review is REJECTED
- Only flag commands where correct and broken give the SAME exit code
```
关键改进：从"请输出表格"改为"复制这个表格并填空"，降低 reviewer 偷懒的可能性。

**Step 1b: 给 Goal Alignment angle 增加填空式模板**
同样改为预填模板：
```
Copy and fill this table for EVERY task:

| Task # | Goal phrase served (quote exact words) | If removed, which Goal phrase loses coverage? |
|--------|---------------------------------------|----------------------------------------------|
| 1 | [quote] | [answer] |
| 2 | ... | ... |

Then copy and fill the coverage matrix:

| Goal phrase (copy from plan header) | Covered by Task #s |
|-------------------------------------|-------------------|
| [phrase 1] | [list] |
```

**Step 2: 给 Completeness angle 增加 scope guard**
在 Completeness angle 的 Mission 中增加：
```
SCOPE: Only analyze functions/branches in files that the plan MODIFIES (listed in Files: fields). 
Do NOT flag functions in files the plan merely reads or references. The plan is not obligated to 
test every function in every file it touches — only the functions it changes.
```

**Step 3: 给所有 random angles 增加 Non-Goals reminder**
在 Random pool 表的表头下方增加一行通用规则：
```
**All angles:** Before writing any finding, verify it is within the plan's stated Goal and 
NOT in Non-Goals. Findings outside scope are noise — discard silently.
```

**Verify:**
```bash
# 验证 planning skill 包含 output format 和 scope guard
grep -q 'Exit code (correct impl)' skills/planning/SKILL.md && grep -q 'SCOPE:' skills/planning/SKILL.md
```

### Task 10: 更新 knowledge 索引

**Files:**
- Modify: `knowledge/INDEX.md`

**Step 1: 添加 Hook Architecture 路由**
在 INDEX.md 的 Routing Table 中添加 Hook Architecture 相关的路由条目。

**Verify:**
```bash
# 验证 INDEX.md 包含 hook architecture 路由
grep -qi 'hook.*architecture\|hook.*design' knowledge/INDEX.md
```

## Review

### Round 1 (2026-02-18)

**Angles:** Goal Alignment + Verify Correctness + Completeness + Clarity

| Reviewer | Verdict | Key Findings |
|----------|---------|-------------|
| Goal Alignment | APPROVE | All goal phrases covered, execution order logical |
| Verify Correctness | APPROVE | 10 verify commands correct, no false positives (shallow review — no per-command trace) |
| Completeness | ~~REQUEST CHANGES~~ → Rejected | Flagged "zero coverage" for existing hook functions (gate_check, gate_brainstorm etc.) — outside Non-Goals scope. Plan is governance/audit, not rewrite/test-all |
| Clarity | APPROVE | All 8 tasks implementable from description alone |

**Calibration:** Completeness reviewer's findings rejected — plan explicitly states Non-Goals include "不重构 pre-write.sh". Testing existing function logic is a separate work item.

**Review quality note:** Verify Correctness reviewer gave blanket APPROVE without per-command exit code traces. Goal Alignment was mechanical. Future rounds should demand structured evidence.

**Post-review additions:**
- Goal updated to include extensibility ("保证新 hook 的接入有清晰流程")
- Task 5 expanded with extensibility design: classification decision tree, new hook checklist, _lib extension rules, event extension points
- Task 8-9 added: reviewer quality fixes (show-your-work requirement, verify output format, scope guard)
- Checklist updated: +3 items for reviewer quality, +1 for extensibility section
- Original Task 8 renumbered to Task 10

**Root cause of review quality issues (3 layers):**
1. reviewer-prompt.md lacks "show your work" enforcement — reviewer can APPROVE without evidence
2. dispatch query Mission copied verbatim from planning skill angle table — too abstract for agent execution
3. Completeness angle mission has no scope guard — reviewer flags functions outside plan's modification scope

### Round 2 (2026-02-18)

**Angles:** Goal Alignment + Verify Correctness + Technical Feasibility + Testability

| Reviewer | Verdict | Quality | Key Findings |
|----------|---------|---------|-------------|
| Goal Alignment | APPROVE | ⬆️ Better — output coverage matrix, identified Task 4 as only removable item | Still somewhat mechanical |
| Verify Correctness | APPROVE | ❌ Still bad — blanket "all sound" without per-item trace despite explicit table requirement in query | Confirms Task 8+9 fixes are necessary |
| Technical Feasibility | APPROVE | ✅ Good — dependency table, 5 specific check points, no false findings | Structured output format worked |
| Testability | APPROVE with findings | ✅ Best — per-item false-negative analysis, found Task 6 advisory weakness | Over-flagged (all 13 "WEAK" assumes adversarial agent) but analysis method correct |

**Key insight from Round 2:** "请输出表格" is ignored, "复制这个表格并填空每个 cell" works. Verify Correctness needs pre-filled template approach (Task 9 strengthened). reviewer-prompt.md needs "Fill the template" rule (Task 8 strengthened).

**Testability finding calibration:** All 13 verify marked "WEAK" because adversarial agent could create fake files. Rejected — verify commands assume honest execution, not adversarial bypass. But Task 6 advisory weakness is valid and already addressed by Socratic self-check (real enforcement is Task 7 validate).

**Verdict: APPROVE (with post-review enhancements)**

### Round 3 (2026-02-18) — 预填模板 + 填空式

**Angles:** Goal Alignment + Verify Correctness + Security + Compatibility & Rollback

| Reviewer | Verdict | Quality | Key Findings |
|----------|---------|---------|-------------|
| Goal Alignment | APPROVE | ⬆️ 中 — 识别 Task 5/7 为 single point of failure，但仍未完整填表 | 可接受 |
| Verify Correctness | REQUEST CHANGES | ✅✅ 优 — 逐条 trace 13 个 verify，发现 #4 sort -nu false negative | **真实 bug，已修复** |
| Security | REQUEST CHANGES | ✅ 良 — data flow trace，2 findings | P0 rejected（enforcement.md 非外部输入），P1 Nit |
| Compatibility & Rollback | APPROVE | ✅✅ 优 — 逐文件搜索 tests/，填完整表格 | 质量最好 |

**Verify Correctness finding 处理：**
- ✅ #4 sort -nu false negative → 已修复：去掉 -u，增加重复检查
- ❌ #8 validate 未实现 → Rejected：Task 7 就是要实现它，verify 在实现后运行

**Security finding 处理：**
- ❌ P0 enforcement.md command injection → Rejected：enforcement.md 是人工维护的项目内文件，非外部输入，Python string matching 不会 shell eval
- ❌ P1 path ANSI injection → Nit：FILE 来自 jq 提取，不存在实际注入路径

**Review 质量总结：** 预填模板方式显著提升了 Verify Correctness 质量（从 blanket APPROVE 到发现真实 bug）。Compatibility & Rollback 质量最好（逐文件搜索 + 完整表格）。Goal Alignment 仍有提升空间但可接受。

**Verdict: APPROVE**

## Checklist

- [x] llm-eval.sh 已移到 .trash | `test ! -f hooks/_lib/llm-eval.sh && test -f .trash/llm-eval.sh`
- [x] enforcement.md 包含所有 15 个 hook | `test $(grep -c '| .hooks/' .kiro/rules/enforcement.md) -ge 15`
- [x] settings.json 包含 enforce-ralph-loop | `jq -r '.. | .command? // empty' .claude/settings.json | grep -q 'enforce-ralph-loop'`
- [x] pre-write.sh Phase 编号连续且无重复 | `grep -oE 'Phase [0-9]+' hooks/gate/pre-write.sh | awk '{print $2}' | sort -n | awk 'NR>1{if($1!=prev+1 || $1==prev){exit 1}}{prev=$1}'`
- [x] session-init.sh 无 delegation reminder | `! grep -q 'Delegation:' hooks/feedback/session-init.sh`
- [ ] Hook Architecture Doc 存在且完整 | `test -f docs/designs/2026-02-18-hook-architecture.md && grep -q '## Design Principles' docs/designs/2026-02-18-hook-architecture.md && grep -q '## Hook Registry' docs/designs/2026-02-18-hook-architecture.md && grep -q '## Lifecycle' docs/designs/2026-02-18-hook-architecture.md && grep -q '## Extensibility' docs/designs/2026-02-18-hook-architecture.md`
- [ ] hooks/ 目录修改有 advisory 提醒 | `echo '{"tool_name":"fs_write","tool_input":{"path":"hooks/security/block-dangerous.sh","file_text":"test","command":"str_replace"}}' | bash hooks/gate/pre-write.sh 2>&1 | grep -q 'Hook file modified'`
- [ ] generate_configs.py --validate 通过 | `python3 scripts/generate_configs.py --validate`
- [ ] docs/INDEX.md 包含 hook architecture 路由 | `grep -qi 'hook.*architecture\|hook.*design' docs/INDEX.md`
- [ ] knowledge/INDEX.md 包含 hook architecture 路由 | `grep -qi 'hook.*architecture\|hook.*design' knowledge/INDEX.md`
- [ ] reviewer-prompt.md 包含 show-your-work 规则 | `grep -q 'Show your work' agents/reviewer-prompt.md && grep -q 'Per-item analysis' agents/reviewer-prompt.md`
- [ ] planning skill 包含 verify output format | `grep -q 'Exit code (correct impl)' skills/planning/SKILL.md`
- [ ] planning skill Completeness angle 有 scope guard | `grep -q 'SCOPE:' skills/planning/SKILL.md`

## Errors

| Error | Task | Attempt | Resolution |
|-------|------|---------|------------|
