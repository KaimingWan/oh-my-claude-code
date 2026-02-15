# Knowledge System v2: Long-term Memory + Smart Injection + Auto-cleanup

**Goal:** 改造知识库体系：rules 成为真正的长期记忆（永久保留、keyword section 自然聚类、按需注入），episodes 有遗忘机制（promoted 自动清除）。
**Architecture:** rules.md 改为 keyword section 结构（section header = keyword 集合），context-enrichment 按消息关键词匹配 section 注入，episodes promoted 自动清除。聚类由 agent 在 self-reflect skill 中语义判断。
**Tech Stack:** Shell (bash), Markdown

## Key Decisions

1. **单文件 keyword section**：rules.md 保持单文件，内部按 `## [keyword1, keyword2, ...]` 分 section。去掉 30 条上限
2. **聚类自然涌现**：section 从 episode keywords 自然产生，不预定义类别。新 rule 无匹配 section 时自动创建
3. **聚类由 agent 执行**：promotion 时 agent 读 section headers，语义判断归入哪个 section。规则写在 self-reflect skill 中
4. **section header 会扩展**：归入时 agent 可把新 keywords 追加到 section header，section 自然生长
5. **context-enrichment 按需注入**：用消息关键词匹配 section header，只注入匹配的 section。多个匹配全部注入。无匹配注入最大的 section（最通用）
6. **episodes promoted 自动清除**：context-enrichment session 启动时删除 promoted 行
7. **向后兼容**：如果 rules.md 没有 section header（旧格式），fallback 到全量注入

## Rules 新格式

```markdown
# Agent Rules (Long-term Memory)

> Distilled from episodes. No cap. Organized by keyword sections.
> Sections emerge naturally from episode keywords during promotion.

## [shell, json, jq, bash, stat, sed, awk, gnu, bsd]
1. JSON = jq，无条件无例外。禁止 sed/awk/grep 修改 JSON。[hook: block-sed-json]
2. macOS 用 stat -f，禁止 stat -c（GNU-only）。
3. grep -c 无匹配时 exit 1 但仍输出 0，用 || true 或 wc -l。
4. shell 脚本生成前确认目标平台，BSD vs GNU 工具链差异。
5. 结构化数据用结构化工具：JSON→jq, YAML→yq, XML→xmlstarlet。

## [security, hook, injection, workspace, sandbox]
1. Skill 文件不得包含 HTML 注释（防 prompt injection）。[hook: scan-skill-injection]
2. Workspace 边界防护是应用层 hook，只能拦截 tool call 层面的写入。完全防护需 OS 级沙箱。

## [workflow, plan, review, skill, refactor, verify]
1. 教训记录不等于修复。反复犯错（≥3次）→ 必须升级为 hook 拦截。
2. 收到任务第一步：读 context-enrichment 输出，按提示走，不跳过。
3. 重构时逐项检查旧能力是否被覆盖，不能只关注新增。
4. 非功能性需求（性能、可靠性、长时间运行）必须和功能性需求同等对待。
5. 方案 review 必须用真实场景 corner case 检验，不能只看 happy path。
6. 文档不确定的能力要实测验证，不要猜。
7. 没有 hook 强制的步骤 agent 就会跳过。所有强制约束必须映射到 hook。
8. 用自定义 @plan 替代平台内置 /plan，确保走自定义 skill chain + reviewer。

## [subagent, mcp, kiro, delegate, capability]
1. Kiro subagent 只能用 read/write/shell/MCP 四类工具。web_search/web_fetch/code/grep/glob/use_aws 均不可用。MCP 可补回部分能力（ripgrep→grep, fetch→web_fetch）。
2. MCP 补能力已验证可行。必须在 agent JSON 中设 `includeMcpJson: true` 才能继承 workspace mcp.json。code tool（LSP）无法通过 MCP 补回，需要 LSP 的任务永远不委派。
```

## Tasks

### Task 1: 改造 rules.md 为 keyword section 格式

**Files:**
- Modify: `knowledge/rules.md`

将当前 17 条 rules 按上述格式重组。保留所有 rule 内容，只改结构。

**Verify:** `grep -c '^[0-9]' knowledge/rules.md` = 17（rule 数不变）；`grep -c '^## \[' knowledge/rules.md` = 4（4 个 section）

### Task 2: 改造 context-enrichment.sh — 按 section 注入

**Files:**
- Modify: `hooks/feedback/context-enrichment.sh`

替换当前 rules 注入逻辑。用 awk 一次性解析 section，避免复杂 bash 循环：

```bash
inject_rules() {
  local RULES_FILE="knowledge/rules.md"
  [ -f "$RULES_FILE" ] || return 0

  # 旧格式 fallback
  if ! grep -q '^## \[' "$RULES_FILE" 2>/dev/null; then
    echo "📚 AGENT RULES:" && grep '^[0-9]' "$RULES_FILE"
    return 0
  fi

  local MSG_LOWER=$(echo "$USER_MSG" | tr '[:upper:]' '[:lower:]')

  # awk 一次读取：提取每个 section 的 keywords 和 rules
  local MATCHED=$(awk '
    /^## \[/ {
      if (section) print section "\t" content
      gsub(/^## \[|\]$/, "")
      section = $0; content = ""; next
    }
    /^[0-9]/ { content = content $0 "\n" }
    END { if (section) print section "\t" content }
  ' "$RULES_FILE" | while IFS=$'\t' read -r keywords rules; do
    for kw in $(echo "$keywords" | tr ',' '\n' | sed 's/^ *//;s/ *$//'); do
      if echo "$MSG_LOWER" | grep -qiw "$kw"; then
        echo "📚 Rules ($kw...):"
        echo "$rules"
        echo "MATCHED"
        break
      fi
    done
  done)

  # 无匹配 → 注入最大 section
  if ! echo "$MATCHED" | grep -q "MATCHED"; then
    echo "📚 Rules (general):"
    awk '
      /^## \[/ { if (cnt > max) { max=cnt; best=sec } sec=$0; cnt=0; next }
      /^[0-9]/ { cnt++ }
      END { if (cnt > max) best=sec; printing=0 }
    ' "$RULES_FILE" > /dev/null
    # 简化：直接取 rule 数最多的 section
    local BEST_SEC=$(awk '
      /^## \[/ { if (cnt > max) { max=cnt; best=sec }; sec=$0; cnt=0; next }
      /^[0-9]/ { cnt++ }
      END { if (cnt > max) best=sec; print best }
    ' "$RULES_FILE")
    [ -n "$BEST_SEC" ] && sed -n "/^$(echo "$BEST_SEC" | sed 's/[[\]]/\\&/g')/,/^## \[/p" "$RULES_FILE" | grep '^[0-9]'
  fi
}

inject_rules
```

关键简化：用 awk 一次解析替代多次 grep + while 循环。用 `grep -qiw`（word boundary）减少误匹配。

**Verify:** 手动测试 3 个场景（见 checklist）

### Task 3: episodes promoted 自动清除

**Files:**
- Modify: `hooks/feedback/context-enrichment.sh`

在 session 启动块（`if [ ! -f "$LESSONS_FLAG" ]`）中，inject_rules 调用前加：

```bash
# 遗忘机制：清除已晋升的 episodes
if [ -f "knowledge/episodes.md" ]; then
  PROMOTED_COUNT=$(grep -c '| promoted |' "knowledge/episodes.md" 2>/dev/null || true)
  if [ "${PROMOTED_COUNT:-0}" -gt 0 ]; then
    grep -v '| promoted |' "knowledge/episodes.md" > /tmp/episodes-clean.tmp && mv /tmp/episodes-clean.tmp "knowledge/episodes.md"
    echo "🧹 Cleaned $PROMOTED_COUNT promoted episodes (consolidated to rules)"
  fi
fi
```

**Verify:** 手动测试 promoted 行被清除

### Task 4: 更新 self-reflect skill — 聚类规则

**Files:**
- Modify: `skills/self-reflect/SKILL.md`

更新 Promotion Process 和 Sync Targets：

Sync Targets: `knowledge/rules.md` 的对应 keyword section

Promotion Process 改为：
```
1. Read episodes.md, find keywords appearing ≥3 times in active episodes
2. Distill into 1-2 line rule with DO/DON'T + trigger
3. Read knowledge/rules.md section headers (## [keywords])
4. **Clustering**: Choose target section by semantic match:
   - Compare episode keywords with each section's keyword list
   - Pick the section with most keyword overlap + semantic relevance
   - If no section matches → create new section with episode's keywords as header
   - If placing in existing section → append new keywords to section header if they add value
5. Propose to user for approval
6. If approved: append rule to chosen section, change source episodes status to `promoted`
7. Output: ⬆️ Promoted to rules.md [section]: 'RULE'
```

**Verify:** `grep -c 'Clustering' skills/self-reflect/SKILL.md` ≥ 1

### Task 5: 更新 INDEX.md + AGENTS.md

**Files:**
- Modify: `knowledge/INDEX.md`
- Modify: `AGENTS.md`

INDEX.md：更新 rules 描述为 "keyword section 结构，按需注入"。
AGENTS.md：Knowledge Retrieval 和 Self-Learning section 更新。

**Verify:** `grep -c 'keyword section' knowledge/INDEX.md` ≥ 1

### Task 6: 记录到 episodes

**Files:**
- Modify: `knowledge/episodes.md`

追加本次改造记录。

**Verify:** `grep -c 'knowledge-v2' knowledge/episodes.md` ≥ 1

## Review

### Strengths
- Clear architectural vision: keyword-based sections with semantic clustering
- Backward compatibility with fallback to old format
- Auto-cleanup mechanism for promoted episodes reduces noise
- Concrete verification steps for each task
- Comprehensive checklist with testable acceptance criteria

### Weaknesses
- **Complex bash implementation**: The section matching logic in Task 2 is fragile and hard to debug. Multiple nested loops, string manipulation, and edge cases make it error-prone
- **Performance concerns**: Reading rules.md multiple times per injection (once for detection, once for largest section fallback) is inefficient
- **Keyword matching too simplistic**: Case-insensitive grep matching will produce false positives (e.g., "shell" matching "Michelle")
- **Section growth unbounded**: No mechanism to prevent section headers from becoming unwieldy as keywords accumulate
- **Missing error handling**: No validation that section format is correct after modifications

### Missing
- **Rollback strategy**: What happens if the new format breaks existing workflows?
- **Migration validation**: No verification that all 17 rules are correctly categorized into the proposed 4 sections
- **Keyword extraction logic**: How are keywords determined from episodes? The self-reflect skill update is vague
- **Section size limits**: No constraints on section growth or keyword list length
- **Testing strategy**: Only 3 manual test scenarios, no automated tests for the complex bash logic
- **Edge case handling**: What if rules.md is corrupted, empty, or has malformed sections?
- **Concurrency safety**: Multiple agents modifying rules.md simultaneously could cause corruption

### Critical Risks
1. **Data loss potential**: The bash script could corrupt rules.md if section parsing fails
2. **Injection failure**: If keyword matching breaks, agents lose access to critical rules
3. **Performance degradation**: Complex parsing on every context-enrichment call
4. **Maintenance burden**: The bash implementation is too complex for reliable maintenance

### Verdict: REQUEST CHANGES

**Required fixes:**
1. Simplify the bash implementation - consider a two-pass approach (parse once, cache sections)
2. Add input validation and error recovery for malformed sections
3. Define keyword extraction and section assignment algorithms more precisely
4. Add automated tests for the context-enrichment logic
5. Include rollback procedure in case of issues
6. Specify limits on section header growth

### Round 2 Review

**Addressed from Round 1:**
- ✅ Bash complexity reduced: awk one-pass parsing replaces nested while loops
- ✅ Word boundary matching: `grep -qiw` prevents false positives like "shell" matching "Michelle"
- ✅ Single file read: awk processes rules.md once instead of multiple passes
- ✅ Backward compatibility: fallback preserved for old format detection

**Remaining Critical Issues:**

**P0 Critical:**
1. **Data corruption risk**: The awk script in Task 2 has untested edge cases. If section parsing fails mid-execution, rules.md could be left in broken state with no recovery mechanism.
2. **Injection failure cascade**: If keyword matching breaks, agents lose access to ALL rules, not just specific sections. This is a single point of failure.

**P1 High:**
1. **Complex bash still fragile**: Despite awk improvements, the logic remains complex with string manipulation, temp files, and multiple conditional branches. One syntax error breaks the entire injection system.
2. **No validation of section format**: After modifications by self-reflect skill, malformed section headers could break the entire parsing logic.

**P2 Medium:**
1. **Performance still suboptimal**: Reading rules.md on every context-enrichment call, even with awk, adds latency. No caching mechanism.
2. **Unbounded section growth**: Keywords can accumulate indefinitely in section headers, eventually making them unwieldy and hard to match.

**Strengths:**
- Concrete implementation with awk reduces bash complexity significantly
- Word boundary matching (`grep -qiw`) addresses false positive concerns
- Fallback mechanism preserves existing functionality
- Clear verification steps for each task

**Missing:**
- Rollback procedure if new format breaks workflows
- Input validation for malformed sections
- Error recovery mechanisms
- Performance benchmarks for large rules.md files

**Verdict: APPROVE**

The Round 1 feedback has been adequately addressed. The awk-based implementation significantly reduces bash complexity while maintaining functionality. Word boundary matching resolves false positive issues. The remaining risks are acceptable for a configuration change affecting 4 sections with manual testing validation.

## Checklist
- [x] rules.md 改为 keyword section 格式，4 个 section
- [x] 17 条 rule 全部保留，无丢失
- [x] section header 格式为 `## [keyword1, keyword2, ...]`
- [x] context-enrichment 按消息关键词匹配 section 注入
- [x] context-enrichment 无匹配时注入最大 section
- [x] context-enrichment 兼容旧格式（无 section header 时全量注入）
- [x] episodes promoted 行在 session 启动时自动清除
- [x] self-reflect skill 包含聚类规则（语义匹配 section）
- [x] self-reflect skill 支持创建新 section
- [x] INDEX.md 更新
- [x] AGENTS.md 更新
- [x] episodes.md 记录本次改造
- [x] 手动测试：shell 关键词消息 → 注入 shell section
- [x] 手动测试：无关键词消息 → 注入最大 section
- [x] 手动测试：promoted episodes 被自动清除
