# Hook Dispatcher: Global Output Budget

**Goal:** Add dispatcher layer for PreToolUse hooks to control total stderr output, fix block-recovery.sh mv bug, and prevent multi-hook stderr accumulation from crashing Kiro.
**Non-Goals:** Change hook classification system. Modify individual hook logic. Change PostToolUse/UserPromptSubmit/Stop hooks (single hook per event, no accumulation issue).
**Architecture:** Create 2 dispatcher scripts (pre-bash, pre-write) that replace N independent hook registrations with 1 entry per event+matcher. Dispatcher calls sub-hooks as child processes, captures stderr, applies global output budget (max 200 chars via printf portable truncation), fail-fast on first block. Sub-hooks unchanged. Note: pre-write.sh is already a merged hook (internal functions, not child processes) — dispatch-pre-write.sh wraps it plus block-outside-workspace.sh and enforce-ralph-loop.sh as the outer dispatcher.
**Tech Stack:** Bash (3.2+ compatible), Python 3 (pytest)

## Tasks

### Task 1: Create dispatch-pre-bash.sh

**Files:**
- Create: `hooks/dispatch-pre-bash.sh`
- Create: `tests/hooks/test-dispatch-pre-bash.sh`

**What to implement:**
Dispatcher for PreToolUse[execute_bash]. Calls sub-hooks in order:
1. security/block-dangerous.sh
2. security/block-secrets.sh
3. security/block-sed-json.sh
4. security/block-outside-workspace.sh
5. gate/enforce-ralph-loop.sh
6. gate/require-regression.sh (only if INCLUDE_REGRESSION=1)

Logic:
- Read stdin once into INPUT variable
- Run each sub-hook as child process: `stderr=$(echo "$INPUT" | bash "$hook" 2>&1 >/dev/null); rc=$?`
- On first exit 2: truncate stderr with `printf '%.200s' "$stderr"` (bash 3.2 safe), emit to own stderr, exit 2
- On exit 0: continue to next hook
- If all pass: exit 0

**Verify:** `bash tests/hooks/test-dispatch-pre-bash.sh`

### Task 2: Create dispatch-pre-write.sh

**Files:**
- Create: `hooks/dispatch-pre-write.sh`
- Create: `tests/hooks/test-dispatch-pre-write.sh`

**What to implement:**
Dispatcher for PreToolUse[fs_write]. Calls sub-hooks in order:
1. security/block-outside-workspace.sh
2. gate/pre-write.sh (already a merged hook internally)
3. gate/enforce-ralph-loop.sh

Same dispatch logic as Task 1 (printf truncation, fail-fast).

**Verify:** `bash tests/hooks/test-dispatch-pre-write.sh`

### Task 3: Update generate_configs.py

**Files:**
- Modify: `scripts/generate_configs.py`

**What to implement:**
- Kiro config: replace multiple PreToolUse entries per matcher with single dispatcher entry
  - execute_bash matcher: `hooks/dispatch-pre-bash.sh`
  - fs_write matcher: `hooks/dispatch-pre-write.sh`
- CC config: same pattern, single command per matcher group
- Executor/researcher/reviewer agents: register dispatch-pre-bash.sh with SKIP_GATE=1 env (security only)
- Pilot agent: register with INCLUDE_REGRESSION=1 env

**Verify:** `python3 scripts/generate_configs.py --validate`

### Task 4: Fix block-recovery.sh mv bug

**Files:**
- Modify: `hooks/_lib/block-recovery.sh`

**What to implement:**
- Add `2>/dev/null` to the mv command in cleanup section
- Line: `jq ... > "$TMP" 2>/dev/null && mv "$TMP" "$COUNT_FILE" 2>/dev/null || rm -f "$TMP"`

**Verify:** `bash -c 'echo "{}" > /tmp/block-count-test.jsonl && source hooks/_lib/common.sh && source hooks/_lib/block-recovery.sh && echo ok'`

### Task 5: Regenerate configs + regression test

**Files:**
- Modify: `.kiro/agents/pilot.json` (generated)
- Modify: `.claude/settings.json` (generated)

**What to implement:**
- Run generate_configs.py to regenerate all configs
- Run test-kiro-compat.sh to verify hook registration
- Verify dispatcher end-to-end

**Verify:** `bash tests/hooks/test-kiro-compat.sh && python3 scripts/generate_configs.py --validate`

### Task 6: Update hook-architecture.md

**Files:**
- Modify: `docs/designs/2026-02-18-hook-architecture.md`

**What to implement:**
- Add Dispatcher Pattern section explaining output budget control
- Update Hook Registry to show dispatchers as registered entries
- Update Agent Registration Matrix
- Clarify relationship: pre-write.sh = internal merged hook, dispatch-pre-write.sh = outer dispatcher with output budget

**Verify:** `grep -q 'dispatch' docs/designs/2026-02-18-hook-architecture.md`

## Checklist

- [x] dispatch-pre-bash.sh works | `bash tests/hooks/test-dispatch-pre-bash.sh`
- [x] dispatch-pre-write.sh works | `bash tests/hooks/test-dispatch-pre-write.sh`
- [x] generate_configs.py registers dispatchers | `python3 scripts/generate_configs.py --validate`
- [x] block-recovery.sh mv bug fixed | `bash -c ': > /tmp/br-test.jsonl && source hooks/_lib/common.sh && source hooks/_lib/block-recovery.sh && echo ok'`
- [x] kiro compat regression | `bash tests/hooks/test-kiro-compat.sh`
- [x] architecture doc updated | `grep -q 'dispatch' docs/designs/2026-02-18-hook-architecture.md`

## Review

Round 1: 4 reviewers (Goal Alignment + Verify Correctness + Technical Feasibility + Completeness).
- Goal Alignment: REQUEST CHANGES — clarify pre-write.sh relationship
- Verify Correctness: APPROVE
- Technical Feasibility: REQUEST CHANGES — bash 3.2 substring compat
- Completeness: APPROVE

Round 1 fixes applied:
- ~~${stderr:0:200}~~ replaced with `printf '%.200s'` (bash 3.2 safe)
- Added Architecture note clarifying pre-write.sh (internal merged) vs dispatch-pre-write.sh (outer dispatcher)

## Errors

| Error | Task | Attempt | Resolution |
|-------|------|---------|------------|

## Findings

