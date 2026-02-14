# Framework v3: Deterministic Overhaul

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 重构 agent 框架，用命令硬编码 + PreToolUse 硬拦截实现确定性触发，激进清理代码和结构，双平台（Kiro + CC）兼容。

**Architecture:** 三层确定性模型 — L1 命令层（用户主动触发完整工作流）、L2 拦截层（PreToolUse block 强制流程）、L3 反馈层（PostToolUse/Stop 提供信息但不阻断）。单一配置源生成双平台配置。

**Tech Stack:** Bash hooks, jq, Kiro agents JSON, CC settings.json

**Affected Features:** 全部 — 这是框架级重写

---

## Phase 1: 归档旧资产 + 建立新目录结构

### Task 1.1: Git tag 回滚点 + 归档

**Files:**
- Create: `archive/v2/` (move old assets here)

**Step 1: 创建回滚点**
```bash
git tag v2-before-v3-overhaul
git push origin v2-before-v3-overhaul
```

**Step 2: 归档非核心资产**
```bash
mkdir -p archive/v2
mv docs/audit/ archive/v2/
mv docs/completed/ archive/v2/
mv docs/plans/2026-02-14-e2e-v3-test-framework.md archive/v2/
mv docs/plans/2026-02-14-adversarial-hook-audit.md archive/v2/
mv docs/research/ archive/v2/
mv tools/e2e-v3/ archive/v2/
mv tools/test-hooks.sh archive/v2/
mv plans/ archive/v2/
mv templates/ archive/v2/
```

**Step 3: 清理空目录和废弃文件**
```bash
rm -rf .claude/skills/self-reflect/{commands}
```

**Step 4: Commit**
```bash
git add -A && git commit -m "chore: archive v2 assets before v3 overhaul"
```

### Task 1.2: 建立新目录结构

**目标结构：**
```
.
├── AGENTS.md                    # 精简到 <60 行
├── CLAUDE.md                    # symlink → AGENTS.md
├── hooks/                       # 统一 hook 源码（不再分 .claude/.kiro）
│   ├── _lib/
│   │   ├── common.sh            # 共享函数（含跨平台兼容）
│   │   ├── patterns.sh          # 安全正则
│   │   └── llm-eval.sh          # LLM 调用
│   ├── security/
│   │   ├── block-dangerous.sh
│   │   ├── block-secrets.sh
│   │   ├── block-sed-json.sh
│   │   └── scan-skill-injection.sh  # 保留（reviewer E2）
│   ├── gate/                    # 新：硬拦截层
│   │   └── require-workflow.sh  # 核心：写代码前必须走流程
│   └── feedback/                # 合并 quality + lifecycle
│       ├── auto-test.sh
│       ├── auto-lint.sh
│       └── verify-completion.sh
├── skills/                      # 统一 skill 源码
│   ├── brainstorming/SKILL.md
│   ├── planning/SKILL.md        # 合并 writing-plans + executing-plans
│   ├── debugging/SKILL.md       # 重命名 systematic-debugging
│   ├── reviewing/SKILL.md       # 合并 code-review-expert + requesting/receiving-code-review
│   ├── research/SKILL.md
│   ├── self-reflect/SKILL.md
│   ├── verification/SKILL.md    # verification-before-completion
│   └── finishing/SKILL.md       # finishing-a-development-branch
├── agents/                      # 统一 agent 定义源码
│   ├── reviewer.md
│   ├── implementer.md
│   ├── debugger.md
│   └── researcher.md
├── commands/                    # 新：自定义命令（Kiro prompts 源）
│   ├── plan.md
│   ├── debug.md
│   ├── research.md
│   ├── review-code.md
│   └── review-plan.md
├── scripts/                     # 新：构建/生成脚本
│   └── generate-platform-configs.sh
├── .claude/                     # 生成的 CC 配置（由脚本生成）
│   ├── settings.json
│   ├── rules/                   # 保留
│   ├── hooks -> ../hooks        # symlink
│   └── skills -> ../skills      # symlink
├── .kiro/                       # 生成的 Kiro 配置（由脚本生成）
│   ├── agents/                  # 生成的 JSON
│   ├── prompts -> ../commands   # symlink
│   ├── hooks -> ../hooks        # symlink
│   ├── skills -> ../skills      # symlink
│   └── rules/                   # 保留
├── knowledge/
│   ├── INDEX.md
│   ├── lessons-learned.md       # 保留
│   └── product/PRODUCT.md
└── docs/
    ├── INDEX.md
    ├── designs/                  # 保留设计文档
    └── plans/                    # 活跃 plan
```

**Step 1: 创建新目录**
```bash
mkdir -p hooks/_lib hooks/security hooks/gate hooks/feedback
mkdir -p skills agents commands scripts
```

**Step 2: 移动 hook 源码到统一位置**
```bash
cp .claude/hooks/_lib/* hooks/_lib/
cp .claude/hooks/security/block-dangerous-commands.sh hooks/security/block-dangerous.sh
cp .claude/hooks/security/block-secrets.sh hooks/security/block-secrets.sh
cp .claude/hooks/security/block-sed-json.sh hooks/security/block-sed-json.sh
cp .claude/hooks/security/scan-skill-injection.sh hooks/security/scan-skill-injection.sh
cp .claude/hooks/quality/auto-test.sh hooks/feedback/auto-test.sh
cp .claude/hooks/quality/auto-lint.sh hooks/feedback/auto-lint.sh
cp .claude/hooks/quality/verify-completion.sh hooks/feedback/verify-completion.sh
cp .claude/hooks/autonomy/context-enrichment.sh hooks/feedback/context-enrichment.sh
```

**Step 3: 建立 symlink**
```bash
# 删除旧的 .kiro symlinks
rm -f .kiro/skills .kiro/hooks

# 新 symlinks
ln -sf ../hooks .claude/hooks
ln -sf ../hooks .kiro/hooks
ln -sf ../skills .claude/skills
ln -sf ../skills .kiro/skills
ln -sf ../commands .kiro/prompts
```

**Step 4: Commit**
```bash
git add -A && git commit -m "refactor: establish v3 unified directory structure"
```

---

## Hook 迁移矩阵

| v2 Hook | v3 去向 | 说明 |
|---------|---------|------|
| `security/block-dangerous-commands.sh` | `security/block-dangerous.sh` | 重命名，逻辑不变 |
| `security/block-secrets.sh` | `security/block-secrets.sh` | 不变 |
| `security/block-sed-json.sh` | `security/block-sed-json.sh` | 不变 |
| `security/scan-skill-injection.sh` | `security/scan-skill-injection.sh` | 保留，路径更新 |
| `quality/enforce-skill-chain.sh` | `gate/require-workflow.sh` | 重写，逻辑简化 |
| `quality/auto-test.sh` | `feedback/auto-test.sh` | 移动，修复 stat 调用 |
| `quality/auto-lint.sh` | `feedback/auto-lint.sh` | 移动，不变 |
| `quality/verify-completion.sh` | `feedback/verify-completion.sh` | 精简 |
| `quality/enforce-tests.sh` | ~~废弃~~ | CC-only TaskCompleted，verify-completion 已覆盖 |
| `quality/reviewer-stop-check.sh` | 合并到 reviewer agent stop hook | 内联为 echo 命令 |
| `autonomy/context-enrichment.sh` | `feedback/context-enrichment.sh` | 精简 |
| `autonomy/auto-approve-safe.sh` | ~~废弃~~ | CC-only PermissionRequest，CC settings.json 直接配置 |
| `autonomy/inject-subagent-rules.sh` | ~~废弃~~ | CC-only SubagentStart，规则写入 agent prompt |
| `lifecycle/session-init.sh` | ~~废弃~~ | 功能合并到 context-enrichment |
| `lifecycle/session-cleanup.sh` | ~~废弃~~ | 无实质功能 |
| `_lib/common.sh` | `_lib/common.sh` | 增强跨平台函数 |
| `_lib/llm-eval.sh` | `_lib/llm-eval.sh` | 不变 |
| `_lib/patterns.sh` | `_lib/patterns.sh` | 不变 |

## Phase 2: 重写核心拦截机制（require-workflow.sh）

### Task 2.1: 重写 common.sh — 跨平台兼容

**Files:**
- Create: `hooks/_lib/common.sh`

**核心改进：**
- `file_mtime()` 实现：
```bash
file_mtime() {
  local f="$1"
  if [[ "$(uname)" == "Darwin" ]]; then
    stat -f %m "$f" 2>/dev/null || echo 0
  else
    stat -c %Y "$f" 2>/dev/null || echo 0
  fi
}
```
- `hook_block()` 保持不变
- `detect_test_command()` 保持不变
- ~~新增 workflow_state_file()~~ ~~废弃：reviewer 指出 /tmp JSON 状态文件有并发竞争问题~~
- 改为直接检查 `docs/plans/` 目录下的文件（无状态，纯文件系统检查）

### Task 2.2: 创建 require-workflow.sh — 核心拦截 hook

**Files:**
- Create: `hooks/gate/require-workflow.sh`

**Plan 发现逻辑（解决 reviewer C3）：**
```bash
find_active_plan() {
  # 找最近修改的 plan 文件，时间窗口内（可配置，默认 4h）
  local WINDOW="${WORKFLOW_PLAN_WINDOW:-14400}"  # 4h in seconds
  local NOW=$(date +%s)
  local LATEST=""
  local LATEST_MTIME=0

  for f in docs/plans/*.md; do
    [ -f "$f" ] || continue
    local mt=$(file_mtime "$f")
    if [ $((NOW - mt)) -lt "$WINDOW" ] && [ "$mt" -gt "$LATEST_MTIME" ]; then
      LATEST="$f"
      LATEST_MTIME="$mt"
    fi
  done

  # fallback: .completion-criteria.md
  if [ -z "$LATEST" ] && [ -f ".completion-criteria.md" ]; then
    local mt=$(file_mtime ".completion-criteria.md")
    if [ $((NOW - mt)) -lt "$WINDOW" ]; then
      LATEST=".completion-criteria.md"
    fi
  fi

  echo "$LATEST"
}
```

**完整逻辑：**
```
PreToolUse[Write|Edit|fs_write] 触发时：
1. 不是源代码文件 → pass
2. 是测试文件 → pass（TDD 允许先写测试）
3. 是 str_replace/Edit（小修改） → pass
4. .skip-plan 存在 → pass（旁路）
5. find_active_plan() 找活跃 plan：
   a. 没找到 → BLOCK "需要先创建 plan"
   b. 找到 → 检查 ## Review section：
      - 内容 <3 行 → BLOCK "需要 reviewer 审查"
      - verdict 是 REJECT/REQUEST CHANGES → BLOCK "plan 被拒绝"
   c. pass
```

**时间窗口：** ~~2h~~ → 4h（可通过 `WORKFLOW_PLAN_WINDOW` 环境变量配置，reviewer W1 建议）

### Task 2.3: 重写 context-enrichment.sh — 精简为纠正检测 + 恢复提醒

**Files:**
- Create: `hooks/feedback/context-enrichment.sh`

**改动：**
- 删除所有"软提醒"逻辑（已证明无效）
- 只保留三个确定性功能：
  1. 纠正检测 → 写 flag 文件（stop hook 会检查）
  2. 未完成任务恢复提醒（.completion-criteria.md）
  3. 高频 lessons 注入（硬编码文本）
- 不再尝试做意图分类或工作流路由（这个交给命令层）

### Task 2.4: 重写 verify-completion.sh — 精简 stop hook

**Files:**
- Create: `hooks/feedback/verify-completion.sh`

**改动：**
- Phase B（确定性检查）保留：completion-criteria 检查、测试运行
- Phase A（LLM eval）保留但简化 prompt
- Phase C（反馈环）精简：只检查纠正 flag + 提醒更新 lessons-learned
- 去掉冗余的 `grep -c ... || true` 模式，统一用 `grep ... | wc -l`
- JSON 状态文件损坏处理：不再使用 JSON 状态文件（reviewer E3 建议）

---

## Phase 3: Skill 合并精简

### Task 3.1: 合并 planning skill

**Files:**
- Create: `skills/planning/SKILL.md`

**合并源：**
- `writing-plans/SKILL.md` + `executing-plans/SKILL.md`
- 一个 skill 覆盖"写 plan"和"执行 plan"两个阶段
- 去掉冗余的模板和示例，保留核心流程

### Task 3.2: 合并 reviewing skill

**Files:**
- Create: `skills/reviewing/SKILL.md`

**合并源：**
- `code-review-expert/SKILL.md` + `requesting-code-review/SKILL.md` + `receiving-code-review/SKILL.md`
- 一个 skill 覆盖"发起 review"、"执行 review"、"接收 review"三个角色

### Task 3.3: 精简其他 skill

**保留并重命名：**
- `brainstorming/` → 保持不变
- `systematic-debugging/` → `debugging/`
- `verification-before-completion/` → `verification/`
- `finishing-a-development-branch/` → `finishing/`
- `self-reflect/` → 保持不变
- `research/` → 保持不变

**删除 — 具体内容去向（解决 reviewer C4）：**

| 被删 Skill | 核心内容 | 合并到 |
|-----------|---------|--------|
| `dispatching-parallel-agents` | 并行 dispatch 模式、独立性判断 | `planning/SKILL.md` → "执行选项 > 并行模式" section |
| `subagent-driven-development` | 每 task 一个 subagent + review | `planning/SKILL.md` → "执行选项 > subagent 模式" section |
| `using-git-worktrees` | worktree 创建/清理命令 | `planning/SKILL.md` → "准备工作 > 隔离工作区" section |
| `test-driven-development` | TDD red-green-refactor 流程 | `planning/SKILL.md` → "Task 结构 > TDD 步骤模板" section |
| `writing-clearly-and-concisely` | Strunk 写作规则 | `knowledge/reference/writing-style.md`（归档） |
| `find-skills` | skill 发现逻辑 | 保留为独立 skill（方便未来扩展） |
| `skill-creator` | skill 创建指南 | `knowledge/reference/skill-creation-guide.md`（归档） |
| `doc-coauthoring` | 文档协作流程 | `knowledge/reference/doc-coauthoring.md`（归档） |
| `humanizer` | AI 写作去痕迹 | `knowledge/reference/humanizer.md`（归档） |
| `mermaid-diagrams` | Mermaid 语法参考 | `knowledge/reference/mermaid-diagrams.md`（归档） |
| `java-architect` | Spring Boot 架构 | `knowledge/reference/java-architect.md`（归档） |
| `requesting-code-review` | 发起 review 流程 | `reviewing/SKILL.md` → "发起 Review" section |
| `receiving-code-review` | 接收 review 流程 | `reviewing/SKILL.md` → "接收 Review" section |
| `code-review-expert` reference 文件 | SOLID 检查清单 | `reviewing/reference.md`（保留为参考） |

**最终 skill 清单（9 个）：**
1. `brainstorming` — 探索需求
2. `planning` — 写 plan + 执行 plan + TDD 步骤模板 + 并行执行策略
3. `reviewing` — 代码/plan review（发起 + 执行 + 接收）
4. `debugging` — 系统化调试
5. `verification` — 完成前验证
6. `finishing` — 分支收尾
7. `self-reflect` — 自学习
8. `research` — 调研
9. `find-skills` — skill 发现（保留，方便未来扩展）

### Task 3.4: Commit
```bash
git add -A && git commit -m "refactor: consolidate 22 skills → 8 core skills"
```

---

## Phase 4: 命令层重写

### Task 4.1: 重写 plan 命令

**Files:**
- Create: `commands/plan.md`

**硬编码完整步骤链：**
```markdown
You MUST follow this exact sequence. Do NOT skip or reorder any step.

## Step 1: Read skills/brainstorming/SKILL.md, explore requirements with user
## Step 2: Read skills/planning/SKILL.md, write plan to docs/plans/<date>-<slug>.md
## Step 3: Dispatch reviewer subagent to challenge the plan
## Step 4: If REJECT/REQUEST CHANGES → fix → re-review → repeat until APPROVE
## Step 5: Show final plan, ask user to confirm
## Step 6: Only after confirmation → execute plan per skills/planning/SKILL.md
```

（与 v2 基本相同，但引用路径更新为新结构）

### Task 4.2: 重写 debug 命令

**Files:**
- Create: `commands/debug.md`

**硬编码：**
```markdown
## Step 1: Read skills/debugging/SKILL.md
## Step 2: Check knowledge/lessons-learned.md for known issues
## Step 3: Follow debugging methodology (reproduce → hypothesize → verify → fix)
```

### Task 4.3: 重写 research 命令

**Files:**
- Create: `commands/research.md`

### Task 4.4: 重写 review-code / review-plan 命令

**Files:**
- Create: `commands/review-code.md`
- Create: `commands/review-plan.md`

### Task 4.5: Commit
```bash
git add -A && git commit -m "refactor: rewrite command layer with hardcoded step chains"
```

---

## Phase 5: 平台配置生成

### Task 5.1: 创建配置生成脚本

**Files:**
- Create: `scripts/generate-platform-configs.sh`

**功能：**
- 读取 `hooks/`、`agents/`、`commands/` 目录
- 生成 `.claude/settings.json`（CC 格式）
- 生成 `.kiro/agents/*.json`（Kiro 格式）
- 单一事实来源，不再手动维护两份配置

**CC settings.json 生成逻辑：**
```bash
jq -n '{
  permissions: {allow: ["Bash(*)", "Read(*)", "Write(*)", "Edit(*)"], deny: []},
  hooks: {
    UserPromptSubmit: [{hooks: [{type: "command", command: "bash hooks/feedback/context-enrichment.sh"}]}],
    PreToolUse: [
      {matcher: "Bash", hooks: [
        {type: "command", command: "bash hooks/security/block-dangerous.sh"},
        {type: "command", command: "bash hooks/security/block-secrets.sh"},
        {type: "command", command: "bash hooks/security/block-sed-json.sh"}
      ]},
      {matcher: "Write|Edit", hooks: [
        {type: "command", command: "bash hooks/gate/require-workflow.sh"},
        {type: "command", command: "bash hooks/security/scan-skill-injection.sh"}
      ]}
    ],
    PostToolUse: [{matcher: "Write|Edit", hooks: [
      {type: "command", command: "bash hooks/feedback/auto-test.sh"},
      {type: "command", command: "bash hooks/feedback/auto-lint.sh"}
    ]}],
    Stop: [{hooks: [{type: "command", command: "bash hooks/feedback/verify-completion.sh"}]}]
  }
}' > .claude/settings.json
```

**Kiro agents JSON 生成逻辑：**
- 从 `agents/*.md` 读取 agent 定义（name, description, tools, resources）
- 从 `hooks/` 映射到 Kiro hook 格式
- 输出到 `.kiro/agents/*.json`

### Task 5.2: 运行生成脚本，验证配置

```bash
bash scripts/generate-platform-configs.sh
# 验证生成的文件
jq . .claude/settings.json
jq . .kiro/agents/default.json
```

### Task 5.3: Commit
```bash
git add -A && git commit -m "feat: single-source config generation for CC + Kiro"
```

---

## Phase 6: AGENTS.md 精简 + knowledge 更新

### Task 6.1: 重写 AGENTS.md

**目标：<60 行，只保留：**
- Identity（2 行）
- Verification First（3 行）
- Workflow（3 行）
- Skill Routing（8 个 skill 的路由表）
- Knowledge Retrieval（3 行）
- Self-Learning（3 行）
- Shell Safety（3 行）
- 指向 rules/ 和 enforcement.md 的引用

**删除：**
- Plan as Living Document（已由命令层硬编码）
- Compound Interest 详细描述（移到 reference.md）
- Long-Running Tasks 详细描述（移到 reference.md）

### Task 6.2: 更新 knowledge/INDEX.md

更新路由表指向新路径。

### Task 6.3: 更新 knowledge/lessons-learned.md

添加 v3 重构的 win 记录。

### Task 6.4: Commit
```bash
git add -A && git commit -m "docs: streamline AGENTS.md and update knowledge index"
```

---

## Phase 6.5: 迁移对比测试（解决 reviewer M2）

### Task 6.5.1: 对比新旧 hook 行为

用相同的输入测试新旧 hook，确保行为一致：

```bash
# 准备测试输入
BLOCK_INPUT='{"tool_name":"fs_write","tool_input":{"file_path":"src/app.ts","command":"create"}}'
PASS_INPUT='{"tool_name":"fs_write","tool_input":{"file_path":"src/app.ts","command":"str_replace","old_str":"a","new_str":"b"}}'
TEST_INPUT='{"tool_name":"fs_write","tool_input":{"file_path":"src/__tests__/app.test.ts","command":"create"}}'

# 对比 enforce-skill-chain vs require-workflow（无 plan 时都应 block create）
echo "$BLOCK_INPUT" | bash .claude/hooks/quality/enforce-skill-chain.sh; echo "v2 exit: $?"
echo "$BLOCK_INPUT" | bash hooks/gate/require-workflow.sh; echo "v3 exit: $?"

# str_replace 都应 pass
echo "$PASS_INPUT" | bash .claude/hooks/quality/enforce-skill-chain.sh; echo "v2 exit: $?"
echo "$PASS_INPUT" | bash hooks/gate/require-workflow.sh; echo "v3 exit: $?"

# test 文件都应 pass
echo "$TEST_INPUT" | bash .claude/hooks/quality/enforce-skill-chain.sh; echo "v2 exit: $?"
echo "$TEST_INPUT" | bash hooks/gate/require-workflow.sh; echo "v3 exit: $?"
```

---

## Phase 7: 端到端验证

### Task 7.1: Hook 功能验证

```bash
# 测试 block-dangerous.sh
echo '{"tool_name":"execute_bash","tool_input":{"command":"rm -rf /"}}' | bash hooks/security/block-dangerous.sh

# 测试 block-sed-json.sh
echo '{"tool_name":"execute_bash","tool_input":{"command":"sed -i s/a/b/ config.json"}}' | bash hooks/security/block-sed-json.sh

# 测试 require-workflow.sh（无 plan 时应 block）
echo '{"tool_name":"fs_write","tool_input":{"file_path":"src/app.ts","command":"create"}}' | bash hooks/gate/require-workflow.sh

# 测试 require-workflow.sh（有 plan + review 时应 pass）
# 先创建一个带 review 的 plan，再测试
```

### Task 7.2: 配置生成验证

```bash
bash scripts/generate-platform-configs.sh
# 验证 JSON 合法
jq . .claude/settings.json > /dev/null && echo "CC config OK"
jq . .kiro/agents/default.json > /dev/null && echo "Kiro config OK"
jq . .kiro/agents/reviewer.json > /dev/null && echo "Reviewer config OK"
```

### Task 7.3: Symlink 验证

```bash
# 验证所有 symlink 指向正确
ls -la .claude/hooks  # → ../hooks
ls -la .claude/skills # → ../skills
ls -la .kiro/hooks    # → ../hooks
ls -la .kiro/skills   # → ../skills
ls -la .kiro/prompts  # → ../commands
```

### Task 7.4: Skill 完整性验证

```bash
# 验证 9 个 skill 都有 SKILL.md 且有 frontmatter
for skill in brainstorming planning reviewing debugging verification finishing self-reflect research find-skills; do
  if [ -f "skills/$skill/SKILL.md" ] && head -1 "skills/$skill/SKILL.md" | grep -q '^---'; then
    echo "✅ $skill"
  else
    echo "❌ $skill MISSING or no frontmatter"
  fi
done
```

### Task 7.5: Final commit + tag

```bash
git add -A && git commit -m "feat: framework v3 — deterministic overhaul complete"
git tag v3.0.0
```

---

## 删除清单（确认）

| 删除项 | 原因 |
|--------|------|
| `.claude/hooks/` 目录（原始文件） | 移到 `hooks/`，.claude/hooks 变为 symlink |
| `.claude/skills/` 目录（原始文件） | 移到 `skills/`，.claude/skills 变为 symlink |
| `.kiro/agents/prompts/` | agent prompt 合并到 `agents/*.md` |
| `.kiro/rules/commands.md` | 命令定义移到 `commands/` |
| `plans/`, `templates/` | 空目录 |
| 13 个被合并/删除的 skill | 见 Task 3.3（find-skills 保留） |
| `docs/audit/`, `docs/completed/`, `docs/research/` | 归档到 `archive/v2/` |
| `tools/e2e-v3/`, `tools/test-hooks.sh` | 归档到 `archive/v2/` |

## 风险

| 风险 | 缓解 |
|------|------|
| 归档后发现需要旧文件 | git tag v2-before-v3-overhaul 可随时恢复 |
| 新 require-workflow.sh 误拦截 | .skip-plan 旁路 + HOOKS_DRY_RUN 模式 |
| 配置生成脚本 bug | 生成后 jq 验证 + 手动 diff 检查 |
| Skill 合并丢失关键内容 | 合并时逐项检查原 skill 的核心流程（见 Task 3.3 映射表） |

## 回滚流程（解决 reviewer M1）

如果 v3 出现严重问题：
```bash
# 1. 恢复到 v2
git stash  # 保存当前未提交的改动
git checkout v2-before-v3-overhaul

# 2. 如果需要在 v2 基础上继续工作
git checkout -b hotfix-from-v2 v2-before-v3-overhaul

# 3. 如果确认 v3 可以放弃
git branch -D main  # 或 git reset --hard v2-before-v3-overhaul
```

## Agent 定义 Markdown 格式（解决 reviewer M3）

`agents/*.md` 文件格式：
```markdown
---
name: reviewer
description: "Review expert. Read-only."
tools: [read, shell]
resources:
  - file://AGENTS.md
  - skill://skills/reviewing/SKILL.md
---

# Reviewer Agent

[System prompt content here]
```

YAML frontmatter 定义元数据，正文是 agent 的 system prompt。
`generate-platform-configs.sh` 解析 frontmatter 生成 JSON。

## 向后兼容（解决 reviewer M4）

- `.completion-criteria.md` — 保持不变，require-workflow.sh 和 verify-completion.sh 都支持
- 现有 `docs/plans/` 中的活跃 plan — 保持不变，新 hook 直接兼容
- `knowledge/lessons-learned.md` — 保持不变
- 环境变量（`HOOKS_DRY_RUN`, `KIRO_EVAL_*`）— 保持不变

## Review

<!-- Reviewer: write your review here -->

### ADVERSARIAL REVIEW - 2026-02-14

**Categorization:** CRITICAL issues found, REQUEST CHANGES required.

#### STRENGTHS
- Clear three-layer deterministic model (L1 commands, L2 PreToolUse blocks, L3 feedback)
- Single-source config generation eliminates dual-maintenance burden
- Aggressive consolidation from 22→8 skills addresses complexity bloat
- Git tag rollback point provides safety net
- Symlink strategy maintains backward compatibility during transition

#### CRITICAL ISSUES

**C1: Missing Hook Migration Strategy**
```bash
# Plan shows copying hooks but missing critical ones:
cp .claude/hooks/quality/auto-test.sh hooks/feedback/auto-test.sh
# ❌ Missing: enforce-skill-chain.sh, reviewer-stop-check.sh, enforce-tests.sh
```
These hooks contain business logic that will be lost. Plan must specify which hooks are being deprecated vs. merged into new hooks.

**C2: Workflow State Race Conditions**
```bash
# /tmp/agent-workflow-<project-hash>.json
# ❌ Multiple agent instances will corrupt this file
```
No file locking mechanism. Concurrent agents (reviewer + implementer) will create race conditions. Need atomic operations or per-agent state files.

**C3: require-workflow.sh Logic Gaps**
```
5. 检查工作流状态：
   a. 最近 2h 内有 plan 文件被创建？ 没有 → BLOCK
```
❌ What if plan exists but is stale (>2h)? What if multiple plans exist? Logic doesn't handle plan file discovery - which plan file to check?

**C4: Skill Consolidation Data Loss Risk**
Plan deletes 14 skills but merge strategy is vague:
- `test-driven-development` → where does TDD methodology go?
- `dispatching-parallel-agents` → "合并到 planning skill" but no concrete mapping
- `using-git-worktrees` → "简化为 planning skill 的一个步骤" loses specialized knowledge

#### WARNINGS

**W1: 2-Hour Time Window Too Aggressive**
```
# 时间窗口从 24h 缩短到 2h（更紧凑）
```
Real development sessions often span >2h. This will create false blocks during legitimate long coding sessions.

**W2: Configuration Generation Script Missing**
Task 5.1 describes `generate-platform-configs.sh` functionality but provides no implementation. Complex jq logic shown but no error handling, validation, or edge case coverage.

**W3: Symlink Dependency Fragility**
```bash
ln -sf ../hooks .claude/hooks
ln -sf ../skills .claude/skills
```
Relative symlinks break if directories are moved. Absolute paths or validation needed.

#### MISSING CRITICAL COMPONENTS

**M1: Rollback Procedure**
Plan creates git tag but no rollback instructions. What if v3 breaks production? Need step-by-step restoration process.

**M2: Migration Testing**
No testing of hook behavior during transition. Need verification that new `require-workflow.sh` produces same blocks/passes as old `enforce-skill-chain.sh` on real scenarios.

**M3: Agent Definition Format**
```
- 从 `agents/*.md` 读取 agent 定义（name, description, tools, resources）
```
No specification of the markdown format. How are tools/resources encoded? What's the schema?

**M4: Backward Compatibility Plan**
What happens to existing `.completion-criteria.md` files? Existing workflow state? Plan assumes clean slate but real systems have persistent state.

#### EDGE CASES NOT ADDRESSED

**E1: Cross-Platform stat() Calls**
```bash
# 新增 `file_mtime()` 函数统一 macOS/Linux stat 差异
```
Plan mentions this but doesn't show implementation. macOS uses `stat -f %m`, Linux uses `stat -c %Y`. Missing implementation = broken hooks.

**E2: Skill Injection Attack Vector**
Plan removes `scan-skill-injection.sh` from security hooks but doesn't explain why this attack vector is no longer relevant.

**E3: JSON Corruption Handling**
Workflow state uses jq but no handling of corrupted JSON files. One bad write breaks entire workflow detection.

#### VERDICT: REQUEST CHANGES

**Required Fixes Before Approval:**

1. **Add hook migration matrix** - explicit mapping of which v2 hooks → v3 hooks, which are deprecated
2. **Implement file locking** for workflow state or use per-agent files  
3. **Define plan discovery logic** - how require-workflow.sh finds the relevant plan file
4. **Provide concrete skill merge mappings** - where does each deleted skill's content go?
5. **Implement generate-platform-configs.sh** with error handling
6. **Add rollback procedure** with step-by-step instructions
7. **Specify agent definition markdown schema**
8. **Show file_mtime() implementation** for cross-platform compatibility

**Recommended Changes:**
- Increase time window to 4h or make configurable
- Add migration testing phase before Phase 7
- Use absolute symlinks or add validation
- Add JSON corruption recovery logic

This is a high-risk, high-reward refactor. The deterministic approach is sound, but execution gaps could break the entire framework. Fix critical issues before proceeding.

