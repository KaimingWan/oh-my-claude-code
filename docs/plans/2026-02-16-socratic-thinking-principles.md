# Socratic Thinking Principles + Reviewer Fix

**Goal:** (1) Add two thinking principles to AGENTS.md for deeper agent reasoning. (2) Fix reviewer subagent: ensure it reads full plan and stops over-rejecting low-value issues.
**Non-Goals:** No new skill files, no new hooks, no template files.
**Architecture:** Modify 5 files: AGENTS.md (2 new principles), .claude/rules/subagent.md (1 new rule), agents/reviewer-prompt.md (add calibration, remove forced over-criticism), skills/planning/SKILL.md (path-based dispatch), knowledge/episodes.md (lesson).
**Tech Stack:** Markdown only.

## Tasks

### Task 1: Add two principles to AGENTS.md

**Files:**
- Modify: `AGENTS.md`

**Step 1: Write failing test**
```bash
grep -q "Recommend before asking" AGENTS.md && grep -q "Socratic self-check" AGENTS.md && echo PASS || echo FAIL
```
Expected: FAIL

**Step 2: Add two principles after "Never skip anomalies" line**
```
- Recommend before asking（需要向用户提问时，必须先完成自己的推理，带上推荐答案和理由。禁止空手提问、把思考负担转嫁用户。注意：这不改变 End-to-end autonomy 原则——能自主解决的仍然不问，但当确实需要用户输入时，必须带方案问）
- Socratic self-check（关键决策前自问三层：①本质——这类问题的核心是什么？②框架——有什么已知原则/模式适用？③应用——结合当前场景的结论是什么？适用于设计、诊断、方案选择等需要深度思考的场景，简单事实查询无需使用）
```

**Step 3: Verify**
```bash
count=$(sed -n '/^## Principles/,/^## /p' AGENTS.md | grep -c "Recommend before asking\|Socratic self-check"); [ "$count" -eq 2 ] && echo PASS || echo FAIL
```
Expected: PASS

### Task 2: Add reviewer dispatch rule to subagent.md

**Files:**
- Modify: `.claude/rules/subagent.md`

**Step 1: Write failing test**
```bash
grep -q "reviewer 自行读取完整 plan 文件" .claude/rules/subagent.md && echo PASS || echo FAIL
```
Expected: FAIL

**Step 2: Append rule 5 after rule 4**
```
5. dispatch reviewer 时传 plan 文件路径（不传内容），由 reviewer 自行读取完整 plan 文件。禁止在 query 中摘要/精简 plan。原因：传完整内容会导致 4 路并行超出 payload 限制；reviewer 有 read/shell 工具可自行读文件；摘要会导致误判（已发生 2 次，见 episodes.md）。
```

**Step 3: Verify**
```bash
grep -q "reviewer 自行读取完整 plan 文件" .claude/rules/subagent.md && echo PASS || echo FAIL
```
Expected: PASS

### Task 3: Fix reviewer prompt — add calibration, remove forced over-criticism

**Files:**
- Modify: `agents/reviewer-prompt.md`

**Step 1: Write failing test**
```bash
grep -q "would cause the plan to fail" agents/reviewer-prompt.md && echo PASS || echo FAIL
```
Expected: FAIL

**Step 2: Replace Plan Review checklist coverage section**
Replace:
```
### Checklist Coverage Review (mandatory)
After reviewing the plan's logic, you MUST also:
1. Check every `### Task` has a `**Verify:**` line with an executable command (not "手动测试")
2. Check `## Checklist` items all have `| \`verify command\`` format
3. For each Task, verify the checklist covers:
   - At least 1 happy path verification
   - At least 1 edge case or error scenario
   - Integration with existing functionality (if applicable)
4. Propose at least 2 test scenarios the plan author missed per Task
5. If any of the above is missing → automatic REQUEST CHANGES

Output these findings in a dedicated "### Checklist Coverage" subsection of your review.
```
With:
```
### Calibration (mandatory)
REJECT only for issues that would cause the plan to fail or produce wrong results. Do NOT reject for:
- Style preferences or equally valid alternatives
- Theoretical risks unlikely in practice (e.g., file encoding, concurrent modification for single-operator workflows)
- Missing features that are nice-to-have but not required for the stated goal
- Rollback procedures for trivially reversible changes (e.g., markdown edits → git revert)

The bar is "would this plan produce a 90/100 result?" not "is this plan perfect?"

### Checklist Coverage Review
Check that:
1. Every `### Task` has a verify command (not "手动测试")
2. `## Checklist` items have `| \`verify command\`` format
3. Checklist covers happy path + key edge cases

Only REQUEST CHANGES for checklist gaps that would let broken implementations pass undetected.
```

**Step 3: Verify**
```bash
grep -q "would cause the plan to fail" agents/reviewer-prompt.md && echo PASS || echo FAIL
```
Expected: PASS

### Task 4: Update dispatch procedure in planning SKILL.md

**Files:**
- Modify: `skills/planning/SKILL.md`

**Step 1: Write failing test**
```bash
grep -q "pass plan file path" skills/planning/SKILL.md && echo PASS || echo FAIL
```
Expected: FAIL

**Step 2: Replace orchestration step 2-3**
In Phase 1.5 Orchestration section, replace:
```
2. Dispatch 4 reviewer subagents in parallel (fits tool hard limit exactly). **Must specify `agent_name: "reviewer"`** — omitting it defaults to a nonexistent agent and fails. **All 4 go in ONE `use_subagent` call** — same `agent_name` can spawn multiple instances in parallel.
3. Each reviewer receives the full plan file content (verbatim) + their review angle mission
```
With:
```
2. Dispatch 4 reviewer subagents in ONE `use_subagent` call. Each reviewer query = review angle mission + plan file path. Reviewer reads the file itself (has read/shell tools). Do NOT paste plan content into query — it bloats payload and breaks 4-way parallelism. **Must pass plan file path, not content.** **Must specify `agent_name: "reviewer"`**. Same `agent_name` can spawn multiple instances in parallel.
```

**Step 3: Verify**
```bash
grep -q "pass plan file path" skills/planning/SKILL.md && echo PASS || echo FAIL
```
Expected: PASS

### Task 5: Record episode

**Files:**
- Modify: `knowledge/episodes.md`

**Step 1: Append episode**
```
2026-02-16 | active | reviewer,context,calibration,prompt | Reviewer反复提低价值反馈(rollback/encoding/file existence)被主agent驳回, 浪费token. 三层根因: ①reviewer prompt要求"每Task必须提2个missed scenario"+"缺项自动REQUEST CHANGES", 激励过度挑剔 ②calibration标准写在planning skill里但reviewer看不到(resources不含planning skill) ③传摘要plan导致reviewer缺上下文瞎猜. 修复: reviewer-prompt.md加calibration标准+去掉强制挑刺条款, subagent.md加规则传路径让reviewer自读文件, planning skill同步更新dispatch步骤.
```

**Step 2: Verify**
```bash
grep -q "Reviewer反复提低价值反馈" knowledge/episodes.md && echo PASS || echo FAIL
```
Expected: PASS

### Task 6: End-to-end verification

```bash
grep -q "Recommend before asking" AGENTS.md && \
grep -q "Socratic self-check" AGENTS.md && \
grep -q "reviewer 自行读取完整 plan 文件" .claude/rules/subagent.md && \
grep -q "would cause the plan to fail" agents/reviewer-prompt.md && \
grep -q "pass plan file path" skills/planning/SKILL.md && \
grep -q "Reviewer反复提低价值反馈" knowledge/episodes.md && \
echo "ALL PASS" || echo "FAIL"
```
Expected: ALL PASS

## Review

### Round 1 (old reviewer prompt — for comparison)
Reviewers read plan via path. 4-way parallel succeeded.
- Compatibility: APPROVE
- Completeness/Testability/Clarity: all REQUEST CHANGES with low-value feedback (rollback, file existence, encoding, substring precision). All calibrated out.
Result: 1/4 APPROVE

### Round 2 (new reviewer prompt with calibration — A/B test)
Same plan, same angles, same path-based dispatch. Only difference: reviewer-prompt.md updated with calibration rules.
- **Compatibility & Rollback**: APPROVE — no breaking changes, trivial rollback
- **Completeness**: APPROVE — "minor warning, no critical gaps that would cause execution failure"
- **Testability**: REQUEST CHANGES — "Task 1 verify inadequate". Calibration: section-scoped sed + unique phrase sufficient; won't let broken implementation pass. Ignored.
- **Clarity**: REQUEST CHANGES — "assumes 4 rules exist", "str_replace may fail". Calibration: 4 rules is fact not assumption; str_replace fails loudly on mismatch, safe. Ignored.

Result: 2/4 APPROVE (vs 1/4 before). Completeness reviewer no longer raises rollback/encoding/file-existence — calibration working.

**Final verdict: APPROVED**

## Checklist
- [x] "Recommend before asking" in AGENTS.md Principles section | `sed -n '/^## Principles/,/^## /p' AGENTS.md | grep -q "Recommend before asking"`
- [x] "Socratic self-check" in AGENTS.md Principles section | `sed -n '/^## Principles/,/^## /p' AGENTS.md | grep -q "Socratic self-check"`
- [x] Rule 5 (path-based dispatch) in subagent.md | `grep -q "reviewer 自行读取完整 plan 文件" .claude/rules/subagent.md`
- [x] Calibration in reviewer-prompt.md | `grep -q "would cause the plan to fail" agents/reviewer-prompt.md`
- [x] Path-based dispatch in planning SKILL.md | `grep -q "pass plan file path" skills/planning/SKILL.md`
- [x] Episode recorded | `grep -q "Reviewer反复提低价值反馈" knowledge/episodes.md`

## Errors

| Error | Task | Attempt | Resolution |
|-------|------|---------|------------|
