# Knowledge Auto-Evolution — Automatic Distillation, Archival & Recall

**Goal:** Make the knowledge system self-evolving: episodes auto-distill into rules, stale episodes auto-archive, and rules auto-inject with severity-based fidelity — all triggered by existing hooks with zero manual intervention.

**Non-Goals:** LLM-based semantic distillation (bash sufficient for current scale). Vector/embedding-based retrieval (keyword matching sufficient). MCP search tools or SQLite storage. Age-based decay (observe buffer usage first). Modifying `.claude/rules/` content (human-curated, out of scope).

**Architecture:** Three-layer change on the existing hook pipeline: (1) `distill.sh` — new library script that scans episodes for distillation candidates, writes rules to `knowledge/rules.md` with severity prefix, and archives promoted episodes. (2) `context-enrichment.sh` — expanded to run distillation on kb-changed flag, inject rules by keyword match every message, and output episode index hints. (3) `session-init.sh` — simplified to cold-start archival + health report only (rules injection moved out). Auto-capture pipeline enhanced with severity tracking via correction flag file.

**Tech Stack:** Bash, awk, grep (hooks layer only — no Python, per shell.md language boundary)

## Research Findings

### Industry Best Practices Integrated

| Practice | Source | How Integrated |
|----------|--------|----------------|
| Episodic→Semantic auto-consolidation | LangMem, SAGE, Bedrock AgentCore | `distill.sh` auto-promotes episodes to rules when keyword freq ≥2 |
| Intelligent Decay (Recency × Relevance × Utility) | Xu 2025 (arxiv 2509.25250) | Simplified: keyword freq as utility proxy, section cap 5 as recency proxy (oldest evicted) |
| Progressive Disclosure (index-first, agent decides depth) | claude-mem docs | Layer 3 recall: episode index hints in context-enrichment, agent reads full file on demand |
| Selective Fidelity (not all memory deserves equal attention) | AFM (Cruz 2025, arxiv 2511.12712) | 🔴 CRITICAL rules force-injected every message; 🟡 RELEVANT rules keyword-matched only |
| "Presence ≠ Influence" (info in context ≠ model uses it) | AFM experiments | 🔴 rules get ⚠️ prefix to boost salience; not buried in long output |
| Noise warning (irrelevant memory degrades performance) | CTIM-Rover (arxiv 2505.23422) | Keyword-scoped injection (not full dump); section cap prevents bloat |
| Archive-not-delete (never lose raw data) | claude-mem, DMS | `knowledge/archive/episodes-YYYY-MM.md` — append-only, never deleted |
| Dual-Layer Hot/Cold path | 2026 industry pattern | Hot=`.claude/rules/` (platform-loaded) + 🔴 rules; Cold=🟡 rules + archive (on-demand) |
| Update via eviction (same-topic new rule replaces old) | LangMem update operation | Section cap 5: oldest rule evicted when new one added = implicit update |

### Key Design Decisions

1. **Bash-only distillation** — Episode summaries are already high-quality (agent-written). Extracting DO/DON'T pattern via grep is sufficient. LLM distillation adds latency/cost/dependency for marginal quality gain at current scale (<50 episodes).
2. **Severity from content, not metadata** — grep for action words (禁止/必须/never/always) → 🔴; else → 🟡. Secondary signal: correction flag file from correction-detect.
3. **Distillation in context-enrichment, not session-init** — Ensures "say it once, effective next message" (0-message delay). session-init would delay by 1 session.
4. **kb-changed flag as dirty check** — 99% of messages skip distillation entirely (no flag = no scan). Only messages after a new episode triggers the full pipeline.
5. **Section cap 5 instead of LLM merge** — When a keyword section exceeds 5 rules, oldest is removed. Simplified Ebbinghaus curve: old rules naturally decay as new ones arrive.

## Tasks

### Task 1: Distillation Engine

**Files:**
- Create: `hooks/_lib/distill.sh`
- Create: `tests/knowledge/test-distill.sh`

**What to implement:**

`distill.sh` is a sourced library with three functions:

1. `distill_check` — Scan episodes.md for active episodes. Count keyword frequency. For keywords with freq ≥2 not covered by rules.md or .claude/rules/*.md: extract newest episode, determine severity (grep action words → 🔴 or 🟡; correction marker → 🔴), write rule to matching section in rules.md (or create new section), mark source episodes as promoted.

2. `archive_promoted` — Move promoted/resolved episodes to `knowledge/archive/episodes-YYYY-MM.md`. Also archive active episodes whose keywords are fully covered by .claude/rules/*.md.

3. `section_cap_enforce` — For each section in rules.md with >5 rules, remove oldest until ≤5.

**Tests:** D1: freq ≥2 triggers distillation with correct severity. D2: keyword in .claude/rules/ → promoted, no rule written. D3: keyword in rules.md → no duplicate. D4: promoted → archive. D5: resolved → archive. D6: archive append-only. D7: section cap (6th evicts 1st). D8: severity: "禁止" → 🔴, no action words → 🟡.

**Verify:** `bash tests/knowledge/test-distill.sh`

### Task 2: Auto-Capture Severity Tracking

**Files:**
- Modify: `hooks/feedback/auto-capture.sh`
- Modify: `hooks/feedback/correction-detect.sh`
- Create: `tests/knowledge/test-severity-tracking.sh`

**What to implement:**

correction-detect touches `/tmp/kb-correction-<WS_HASH>-$$.flag` (PID-scoped to avoid cross-session race) BEFORE calling auto-capture. auto-capture checks for any matching flag `/tmp/kb-correction-<WS_HASH>-*.flag`: if present, append ` [correction]` to episode keyword field as metadata marker. Remove matching flags after capture. This lets distill.sh use correction origin as secondary severity signal.

Also fix auto-capture Gate 4: change `grep -c "$DATE_PATTERN"` to `grep -cE '\| (active|resolved|promoted) \|'` for accurate episode counting.

**Tests:** S1: correction-detect sets flag before auto-capture. S2: auto-capture appends [correction] when flag exists. S3: flag cleaned up after capture. S4: non-correction capture has no marker. G1: Gate 4 correctly blocks at capacity 30.

**Verify:** `bash tests/knowledge/test-severity-tracking.sh`

### Task 3: Context-Enrichment Expansion

**Files:**
- Modify: `hooks/feedback/context-enrichment.sh`
- Modify: `hooks/feedback/session-init.sh`
- Create: `tests/knowledge/test-enrichment-v2.sh`

**What to implement:**

Expand context-enrichment.sh:

1. **Distillation trigger:** Check kb-changed flag → source distill.sh, call distill_check + archive_promoted + section_cap_enforce. Remove flag.

2. **Rules injection (moved from session-init):** Extract keywords from user message. Match against rules.md section headers. Inject with severity formatting: 🔴 → `⚠️ RULE: <text>`, 🟡 → `📚 Rule: <text>`.

3. **🔴 always-inject:** Scan all sections for 🔴 rules, inject regardless of keyword match.

4. **Episode index hints:** Scan episodes.md for active episodes matching user keywords. Output first 40 chars as hints.

5. **Archive hint:** If knowledge/archive/ non-empty, output path hint.

Simplify session-init.sh: remove inject_rules function. Keep promoted cleanup (cold-start fallback), promotion count, health report.

**Tests:** E1: kb-changed flag triggers distillation. E2: 🟡 rules injected with 📚 on keyword match. E3: 🔴 rules always injected with ⚠️. E4: episode hints for matching keywords. E5: archive hint when dir exists. E6: session-init no longer outputs rules. E7: session-init still does cleanup + health. E8: no distillation when flag absent.

**Verify:** `bash tests/knowledge/test-enrichment-v2.sh`

### Task 4: Integration Test & Scaffold

**Files:**
- Create: `knowledge/archive/.gitkeep`
- Modify: `knowledge/rules.md`
- Create: `tests/knowledge/test-integration.sh`

**What to implement:**

1. Create `knowledge/archive/` with `.gitkeep`.
2. Update rules.md header to document new format:
```markdown
# Agent Rules — Staging Area

> Auto-distilled from episodes. Injected by context-enrichment per message.
> 🔴 = CRITICAL (always injected) | 🟡 = RELEVANT (keyword-matched)
> Sections auto-created by distill.sh. Max 5 rules per section.
```

3. End-to-end integration test: setup temp workspace → write episodes with shared keyword → touch kb-changed → run context-enrichment → verify rule in rules.md + output contains rule + episodes promoted → run session-init → verify archive populated.

**Verify:** `bash tests/knowledge/test-integration.sh`

### Task 5: Existing Test Regression

**Files:**
- Modify: `tests/knowledge/l1-rules-injection.sh` (adapt to new injection source)
- Modify: `tests/knowledge/l1-corruption-recall.sh` (adapt to new cleanup location)

**What to implement:**

Existing knowledge tests expect rules injection from session-init. After Task 3, injection moves to context-enrichment. Update test helpers and assertions to match new hook responsibilities:
- `run_context_enrichment` calls should now return rules output
- `run_session_init` calls should NOT return rules output
- Promoted cleanup tests should verify both session-init (cold-start) and context-enrichment (hot-path) paths

**Verify:** `bash tests/knowledge/l1-rules-injection.sh && bash tests/knowledge/l1-corruption-recall.sh`

### Task 6: Hook Compatibility Verification

**Files:**
- (no new files — verification only)

**What to implement:**

Run existing hook compatibility tests to ensure changes don't break Kiro/CC hook format expectations. Fix any failures.

**Verify:** `bash tests/hooks/test-kiro-compat.sh`

### Task 7: Review Quality — Specific Questions + Canary Verification

**Files:**
- Modify: `skills/planning/SKILL.md`
- Modify: `skills/reviewing/SKILL.md`

**What to implement:**

Three changes to the review dispatch mechanism:

1. **Specific Questions section in dispatch template** — Add a `## Specific Questions for This Plan` section to the Dispatch Query Template in `skills/planning/SKILL.md`. Main agent MUST fill 2-3 plan-specific risk points before dispatching. Reviewer MUST answer each question explicitly. Template:
```
## Specific Questions for This Plan
Answer each question with evidence (file:line or shell output). Unanswered = review REJECTED.
1. [risk question identified by main agent]
2. [risk question identified by main agent]
```

2. **Canary question in Mandatory Source Reading** — Add to the dispatch template: one question per dispatch that can ONLY be answered by reading a specific source file. Example: "What is the first line of function X in file Y?" If reviewer answers incorrectly or skips, their source-reading claims are unreliable. Add to planning SKILL.md dispatch template:
```
## Source Reading Canary
Answer this BEFORE your analysis. Wrong answer = review REJECTED.
Q: [question only answerable by reading specific source file]
```

3. **Pre-review checklist in reviewing SKILL.md** — Add to "Plan Review" section: before dispatching, main agent must identify 2-3 specific risk points from the plan and formulate them as questions. This is the "pre-review" step that focuses reviewer attention.

**Verify:** `grep -q 'Specific Questions' skills/planning/SKILL.md && grep -q 'Source Reading Canary' skills/planning/SKILL.md && grep -q 'pre-review' skills/reviewing/SKILL.md`

## Review

Round 1 (4 reviewers parallel):
- Goal Alignment: APPROVE — all 6 tasks map to goal phrases, execution order valid
- Verify Correctness: APPROVE — all 6 verify commands sound with clear pass/fail
- Completeness: APPROVE — all modified files' functions and error paths covered
- Technical Feasibility: REQUEST CHANGES — 2 findings:
  - F1: correction flag race condition with concurrent sessions. **Accepted**: changed to PID-scoped flag `/tmp/kb-correction-<WS_HASH>-$$.flag`
  - F2: archive append not atomic. **Rejected**: POSIX guarantees atomic `>>` for writes <PIPE_BUF (512 bytes), episode lines are <200 bytes

Round 2 (2 fixed angles, verifying fix):
- Goal Alignment: APPROVE — PID-scoped flag maintains goal alignment and execution order
- Verify Correctness: APPROVE — tests S1-S4 cover glob-based detection correctly

## Checklist

- [ ] distill.sh 蒸馏引擎通过单元测试 | `bash tests/knowledge/test-distill.sh`
- [ ] severity 追踪通过测试 | `bash tests/knowledge/test-severity-tracking.sh`
- [ ] context-enrichment v2 通过测试 | `bash tests/knowledge/test-enrichment-v2.sh`
- [ ] 端到端集成测试通过 | `bash tests/knowledge/test-integration.sh`
- [ ] 现有知识库测试不回归 | `bash tests/knowledge/l1-rules-injection.sh && bash tests/knowledge/l1-corruption-recall.sh`
- [x] hook 兼容性测试通过 | `bash tests/hooks/test-kiro-compat.sh`
- [ ] review 质量改进写入 skill 文件 | `grep -q 'Specific Questions' skills/planning/SKILL.md && grep -q 'Source Reading Canary' skills/planning/SKILL.md && grep -q 'pre-review' skills/reviewing/SKILL.md`

## Errors

| Error | Task | Attempt | Resolution |
|-------|------|---------|------------|
