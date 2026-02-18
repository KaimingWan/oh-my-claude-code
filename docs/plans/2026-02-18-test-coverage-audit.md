# Test Coverage & Quality Audit (Layer 1-3)

**Goal:** Audit existing test coverage for completeness and quality across Layer 1 (pytest), Layer 2 (shell integration), and Layer 3 (knowledge tests). Fix stale/broken tests, fill coverage gaps. Additionally, improve reviewer subagent quality based on this round's review findings.
**Non-Goals:** Layer 4 (CC integration tests requiring `claude` CLI). Adding tests for docs, skills, or commands. Rewriting working tests.
**Architecture:** Audit-first approach — build coverage matrix, identify gaps, fix broken tests, then add minimal new tests for uncovered critical paths.
**Tech Stack:** Python (pytest), Bash (shell tests), jq

## Coverage Matrix (Current State)

### Source → Test Mapping

| Source File | Test File(s) | Coverage Level | Gaps |
|-------------|-------------|----------------|------|
| `scripts/ralph_loop.py` | `tests/ralph-loop/test_ralph_loop.py` (30 tests) | ✅ High | — |
| `scripts/lib/plan.py` | `tests/ralph-loop/test_plan.py` (23 tests) | ✅ High | `unchecked_tasks()` only tested indirectly |
| `scripts/lib/scheduler.py` | `tests/ralph-loop/test_scheduler.py` (17 tests) | ✅ High | — |
| `scripts/lib/lock.py` | `tests/ralph-loop/test_lock.py` (5 tests) | ✅ Good | — |
| `scripts/lib/cli_detect.py` | `tests/ralph-loop/test_ralph_loop.py` (4 tests) | ✅ Good | — |
| `scripts/generate_configs.py` | `tests/test_generate_configs.py` (6 tests) | ✅ Good | `validate()` not tested |
| `hooks/security/block-dangerous.sh` | `test-cc-compat.sh`, `test-kiro-compat.sh`, `test-block-recovery.sh` | ✅ Good | — |
| `hooks/security/block-secrets.sh` | `test-cc-compat.sh`, `test-kiro-compat.sh` | ⚠️ Medium | No test for git commit staged-file scan |
| `hooks/security/block-sed-json.sh` | `test-cc-compat.sh`, `test-kiro-compat.sh`, `test-block-recovery.sh` | ✅ Good | — |
| `hooks/security/block-outside-workspace.sh` | `test-cc-compat.sh`, `test-kiro-compat.sh`, `test-block-recovery.sh` | ✅ Good | — |
| `hooks/gate/pre-write.sh` | `test-cc-compat.sh`, `test-kiro-compat.sh`, `test-write-protection.sh`, `test-brainstorm-gate.sh` | ✅ Good | `gate_plan_structure` + `gate_checklist` + `scan_content` not directly tested |
| `hooks/gate/enforce-ralph-loop.sh` | `test-enforcement.sh` (20 tests) | ⚠️ 4 STALE | T1/T4/T7/T17 test old behavior |
| `hooks/gate/require-regression.sh` | `test-cc-compat.sh` (passthrough only) | ❌ No real test | Only tests non-commit passthrough |
| `hooks/feedback/correction-detect.sh` | `test-split.sh` | ⚠️ Shallow | Only tests Chinese correction, not English patterns |
| `hooks/feedback/session-init.sh` | `test-kiro-compat.sh`, `test-cc-compat.sh` | ⚠️ Shallow | Only tests exit 0, no logic verification |
| `hooks/feedback/context-enrichment.sh` | `test-split.sh` | ⚠️ Medium | Research reminder tested, unfinished task resume not tested |
| `hooks/feedback/post-write.sh` | `test-kiro-compat.sh`, `test-cc-compat.sh` | ⚠️ Shallow | Only tests exit 0, no lint/test/remind logic |
| `hooks/feedback/post-bash.sh` | `test-kiro-compat.sh`, `test-cc-compat.sh` | ⚠️ Shallow | Only tests exit 0, no verify-log write verification |
| `hooks/feedback/verify-completion.sh` | `test-kiro-compat.sh`, `test-cc-compat.sh` | ⚠️ Shallow | Only tests exit 0 + stop_hook_active, no checklist/verify logic |
| `hooks/feedback/auto-capture.sh` | None | ❌ No test | Complex pipeline, zero coverage |
| `hooks/feedback/kb-health-report.sh` | None | ❌ No test | Report generation untested |
| `hooks/_lib/common.sh` | Indirectly via all hook tests | ⚠️ Indirect | `find_active_plan` time-window fallback not tested |
| `hooks/_lib/patterns.sh` | Indirectly via security hook tests | ✅ Indirect OK | — |
| `hooks/_lib/block-recovery.sh` | `test-block-recovery.sh` | ✅ Good | — |

### Quality Issues Found

1. **4 stale tests in test-enforcement.sh** — T1 (`mkdir -p foo`), T4 (`cat foo && mkdir bar`), T7 (stale lock + mkdir), T17 (`cat foo | tee bar`). Hook was updated to allow `mkdir`/`touch`/`unlink` as safe markers and `cat` as read-only. Tests still expect block.
2. **generate_configs.py `validate()` untested** — The hook registry consistency checker has no test.
3. **require-regression.sh has no real test** — Only passthrough tested, never the actual "block commit without recent pytest" logic.
4. **auto-capture.sh has zero tests** — Complex 4-gate pipeline with keyword extraction, dedup, capacity check.
5. **kb-health-report.sh has zero tests** — Report generation, promotion candidate detection.
6. **Feedback hooks tested only for exit 0** — post-bash verify-log writing, verify-completion checklist re-run, session-init rules injection — all untested for actual behavior.

## Tasks

### Task 1: Fix 4 Stale Enforcement Tests

**Files:**
- Modify: `tests/ralph-loop/test-enforcement.sh`

**Step 1: Update T1, T4, T7, T17 to use commands that SHOULD be blocked**
- T1: `mkdir -p foo` → now allowed (safe marker). Change to `python3 -c "import os"` (not in allowlist).
- T4: `cat foo && mkdir bar` → both in allowlists. Change to `python3 x.py && echo done` (python not in allowlist).
- T7: stale lock test uses `mkdir x` which is now allowed. Change to `python3 -c "pass"` (not in allowlist).
- T17: `cat foo | tee bar` → cat is read-only. Change to `python3 x.py | tee bar` (python not in allowlist).

**Verify:** `bash tests/ralph-loop/test-enforcement.sh`

---

### Task 2: Add generate_configs.py validate() Test

**Files:**
- Modify: `tests/test_generate_configs.py`

**Step 1: Add test for validate()**
Test that `validate()` returns 0 when hook registry is consistent (current state).

**Verify:** `python3 -m pytest tests/test_generate_configs.py -v`

---

### Task 3: Add require-regression.sh Real Tests

**Files:**
- Create: `tests/hooks/test-require-regression.sh`

**Step 1: Test commit-with-ralph-files blocked without recent pytest**
Stage a ralph file, ensure no recent pytest cache, verify exit 2.

**Step 2: Test commit-with-ralph-files allowed after pytest**
Touch pytest cache to simulate recent run, verify exit 0.

**Step 3: Test non-ralph commit always passes**
Stage a non-ralph file, verify exit 0.

**Verify:** `bash tests/hooks/test-require-regression.sh`

---

### Task 4: Add auto-capture.sh Tests

**Files:**
- Create: `tests/hooks/test-auto-capture.sh`

**Step 1: Test gate 1 — question filtered**
Input ending with `?` → exit 1.

**Step 2: Test gate 1 — no action keyword filtered**
Input without action keywords → exit 1.

**Step 3: Test gate 2 — no English keywords filtered**
Input with only Chinese/short words → exit 1.

**Step 4: Test happy path — capture written to episodes.md**
Valid correction with action keyword → new line in episodes.md. Verify line contains date, "active", and extracted keywords.

**Step 5: Test gate 3 — duplicate skipped**
Same keyword already in episodes → exit 0, no new line added (line count unchanged).

**Step 6: Test gate 4 — capacity check**
Episodes at 30 entries → exit 0, no new line added (line count unchanged).

**Verify:** `bash tests/hooks/test-auto-capture.sh`

---

### Task 5: Add post-bash.sh Verify-Log Test

**Files:**
- Modify: `tests/hooks/test-kiro-compat.sh`

**Step 1: Add test that post-bash writes to verify log**
Send a bash command, check that `/tmp/verify-log-*.jsonl` gets an entry. Verify JSON structure: has `cmd_hash`, `cmd`, `exit_code`, `ts` fields. Verify `cmd_hash` matches expected shasum of the command.

**Verify:** `bash tests/hooks/test-kiro-compat.sh`

---

### Task 6: Add correction-detect.sh English Pattern Test

**Files:**
- Modify: `tests/context-enrichment/test-split.sh`

**Step 1: Add English correction detection test**
Input "you are wrong" → output contains CORRECTION.

**Step 2: Add negative test — non-correction should NOT trigger**
Input "hello world" → output does NOT contain CORRECTION.

**Verify:** `bash tests/context-enrichment/test-split.sh`

---

### Task 7: Improve Reviewer Quality (3 fixes)

**Files:**
- Modify: `agents/reviewer-prompt.md`
- Modify: `.claude/agents/reviewer.md`
- Modify: `skills/planning/SKILL.md`

**Fix 1: Add verdict mandate to reviewer prompt**
Add to both `agents/reviewer-prompt.md` and `.claude/agents/reviewer.md` after Output Quality Rules:
```
5. **Verdict is mandatory** — Your response MUST end with exactly one of:
   - `**Verdict: APPROVE**`
   - `**Verdict: REQUEST CHANGES**` followed by the P0/P1 items that must be fixed
   Missing verdict = review is INVALID and will be discarded by the orchestrator.
```

**Fix 2: Add source reading mandate to planning skill dispatch template**
Add to `skills/planning/SKILL.md` Dispatch Query Template, after Anti-patterns:
```
## Mandatory Source Reading
Before making ANY claim about code behavior, you MUST:
1. Read the actual source file (use Bash: cat <file>)
2. Cite the specific line number in your finding
3. If you haven't read the file, do NOT speculate — read it first
Findings about code behavior without file:line citations will be discarded.
```

**Fix 3: Make Goal Alignment mission more concrete in planning skill**
In `skills/planning/SKILL.md` Angle Pool, update Goal Alignment mission to add explicit instruction:
```
You MUST copy each table below and fill EVERY cell. Do NOT summarize or skip rows.
If a table has N tasks, your output must have N rows. Missing rows = review REJECTED.
```

**Verify:** `grep -q 'Verdict is mandatory' agents/reviewer-prompt.md && grep -q 'Mandatory Source Reading' skills/planning/SKILL.md && grep -q 'Missing rows = review REJECTED' skills/planning/SKILL.md`

---

## Review

### Round 1 (4 reviewers parallel)

**Goal Alignment:** Task 1 strategy questioned — reviewer suggested changing test expectations to exit 0 instead of changing commands. Rejected: weakening security tests is wrong. We change to commands that SHOULD be blocked (python3) to maintain test intent.

**Verify Correctness:** Commands 2-5 test for not-yet-created files (by design — TDD). Command 6 was too broad (any "PASS" match) — fixed to match English-specific test name. Command 7 sound.

**Completeness:** APPROVE — all gaps addressed, error paths covered.

**Testability:** Valid feedback on assertion depth. Applied fixes:
- Task 4: verify episodes.md content format (date, status, keywords), not just exit codes
- Task 5: verify JSON structure and cmd_hash accuracy
- Task 6: added negative test case

**Post-review addition:** Task 7 (reviewer quality) added per user request — addresses 3 new findings from this review round:
1. Reviewers not reading source before claiming code behavior (episodes #32 pattern)
2. No explicit verdict in output
3. Goal Alignment mission too abstract vs Completeness/Testability

**Verdict: APPROVE (after fixes applied)**

## Checklist

- [ ] 4 stale enforcement tests fixed, all 20 pass | `bash tests/ralph-loop/test-enforcement.sh 2>&1 | grep -q '20/20 passed'`
- [ ] generate_configs validate() tested | `python3 -m pytest tests/test_generate_configs.py::test_validate_hook_registry -v`
- [ ] require-regression real tests exist and pass | `bash tests/hooks/test-require-regression.sh`
- [ ] auto-capture tests exist and pass | `bash tests/hooks/test-auto-capture.sh`
- [ ] post-bash verify-log write tested | `bash tests/hooks/test-kiro-compat.sh 2>&1 | grep -q 'PASS.*post-bash.*verify-log'`
- [ ] English correction detection tested | `bash tests/context-enrichment/test-split.sh 2>&1 | grep -q 'PASS.*English\|English.*PASS'`
- [ ] 既有测试无回归 | `python3 -m pytest tests/ralph-loop/ tests/test_generate_configs.py -q && bash tests/hooks/test-kiro-compat.sh 2>&1 | tail -1 | grep -q '0 failed' && bash tests/hooks/test-cc-compat.sh 2>&1 | tail -1 | grep -q '0 failed'`
- [ ] reviewer prompt 加 verdict 强制 + source reading mandate + goal alignment 具体化 | `grep -q 'Verdict is mandatory' agents/reviewer-prompt.md && grep -q 'Mandatory Source Reading' skills/planning/SKILL.md && grep -q 'Missing rows = review REJECTED' skills/planning/SKILL.md`

## Errors

| Error | Task | Attempt | Resolution |
|-------|------|---------|------------|
