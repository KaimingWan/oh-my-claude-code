# Hook Governance: Reduce False Positives + Slim Output

**Goal:** enforce-ralph-loop.sh allowlist to denylist, narrow block-dangerous/outside-workspace false positives, compress all hook output to reduce context pollution.
**Non-Goals:** Change hook 3-category architecture. Rewrite ralph-loop core. Add new hooks. Change registration mechanism.
**Architecture:** (1) enforce-ralph-loop.sh flip to denylist (2) dangerous/outside-workspace narrowing (3) hook output compression
**Tech Stack:** Bash, Python 3 (pytest)

## Tasks

### Task 1: enforce-ralph-loop.sh denylist refactor

**Files:**
- Modify: `hooks/gate/enforce-ralph-loop.sh`
- Create: `tests/hooks/test-ralph-gate.sh`

**What to implement:**
- Add extract_protected_files() to parse plan Files: fields
- bash mode: allow by default, only block writes to protected files
- fs_write mode: allow if file not in protected list
- Keep: .active guard, lock check, skip bypass

**Verify:** `bash tests/hooks/test-ralph-gate.sh`

### Task 2: block-dangerous.sh narrowing

**Files:**
- Modify: `hooks/security/block-dangerous.sh`
- Modify: `hooks/_lib/patterns.sh`
- Modify: `tests/hooks/verify-block-dangerous.sh`

**What to implement:**
- git branch pattern: only block force delete (uppercase D)
- Remove overly broad process signal patterns
- find with delete: only block on system paths

**Verify:** `bash tests/hooks/verify-block-dangerous.sh`

### Task 3: block-outside-workspace.sh allow /tmp/

**Files:**
- Modify: `hooks/security/block-outside-workspace.sh`
- Create: `tests/hooks/test-outside-workspace.sh`

**What to implement:**
- Remove /tmp/ from OUTSIDE_WRITE_PATTERNS

**Verify:** `bash tests/hooks/test-outside-workspace.sh`

### Task 4: Block message single-line

**Files:**
- Modify: `hooks/_lib/block-recovery.sh`
- Modify: `hooks/_lib/common.sh`
- Modify: `hooks/security/block-dangerous.sh`
- Modify: `hooks/security/block-secrets.sh`
- Modify: `hooks/security/block-sed-json.sh`
- Modify: `hooks/security/block-outside-workspace.sh`
- Create: `tests/hooks/test-block-output.sh`

**What to implement:**
- hook_block() single line output
- hook_block_with_recovery() compressed format
- All security hooks pass single-line messages

**Verify:** `bash tests/hooks/test-block-output.sh`

### Task 5: context-enrichment.sh output budget + dedup

**Files:**
- Modify: `hooks/feedback/context-enrichment.sh`
- Create: `tests/hooks/test-context-budget.sh`

**What to implement:**
- Output truncation max 8 lines
- 60s dedup
- Rules injection cap 3

**Verify:** `bash tests/hooks/test-context-budget.sh`

### Task 6: Feedback hook output slimming

**Files:**
- Modify: `hooks/gate/pre-write.sh`
- Modify: `hooks/feedback/post-write.sh`
- Modify: `hooks/feedback/verify-completion.sh`
- Create: `tests/hooks/test-feedback-output.sh`

**What to implement:**
- pre-write: always 1-line summary
- post-write: failure tail -3
- verify-completion: summary only

**Verify:** `bash tests/hooks/test-feedback-output.sh`

### Task 7: Regression test + doc update

**Files:**
- Modify: `docs/designs/2026-02-18-hook-architecture.md`

**What to implement:**
- Run test-kiro-compat.sh
- Update hook-architecture.md
- Validate configs

**Verify:** `bash tests/hooks/test-kiro-compat.sh && python3 scripts/generate_configs.py --validate`

## Checklist

- [x] enforce-ralph-loop denylist mode | `bash tests/hooks/test-ralph-gate.sh`
- [x] block-dangerous narrowed | `bash tests/hooks/verify-block-dangerous.sh`
- [x] block-outside-workspace allows /tmp/ | `bash tests/hooks/test-outside-workspace.sh`
- [x] block output <=3 lines | `bash tests/hooks/test-block-output.sh`
- [x] context-enrichment output <=8 lines | `bash tests/hooks/test-context-budget.sh`
- [x] feedback output slimmed | `bash tests/hooks/test-feedback-output.sh`
- [ ] regression tests pass | `bash tests/hooks/test-kiro-compat.sh`
- [ ] config validation passes | `python3 scripts/generate_configs.py --validate`

## Review

4 reviewers dispatched (Goal Alignment + Verify Correctness + Completeness + Technical Feasibility).
All 4 returned Verdict: APPROVE.

## Errors

| Error | Task | Attempt | Resolution |
|-------|------|---------|------------|

## Findings

