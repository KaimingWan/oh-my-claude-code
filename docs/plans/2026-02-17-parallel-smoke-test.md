# Parallel Dispatch Smoke Test

**Goal:** Verify ralph_loop.py batch scheduler and parallel subagent dispatch work end-to-end.
**Non-Goals:** Not testing complex scenarios. Just a smoke test.
**Architecture:** 3 independent tasks (no file overlap) + 1 dependent task.
**Tech Stack:** Bash (touch files)

## Review
Smoke test — no review needed.

## Tasks

### Task 1: Create file alpha

**Files:**
- Create: `/tmp/ralph-test-alpha.txt`

**Verify:** `test -f /tmp/ralph-test-alpha.txt`

Create `/tmp/ralph-test-alpha.txt` with content "alpha".

---

### Task 2: Create file beta

**Files:**
- Create: `/tmp/ralph-test-beta.txt`

**Verify:** `test -f /tmp/ralph-test-beta.txt`

Create `/tmp/ralph-test-beta.txt` with content "beta".

---

### Task 3: Create file gamma

**Files:**
- Create: `/tmp/ralph-test-gamma.txt`

**Verify:** `test -f /tmp/ralph-test-gamma.txt`

Create `/tmp/ralph-test-gamma.txt` with content "gamma".

---

### Task 4: Combine into result

**Files:**
- Create: `/tmp/ralph-test-result.txt`
- Modify: `/tmp/ralph-test-alpha.txt`

**Verify:** `test -f /tmp/ralph-test-result.txt`

Concatenate alpha + beta + gamma into `/tmp/ralph-test-result.txt`.

## Checklist
- [ ] alpha file created | `test -f /tmp/ralph-test-alpha.txt`
- [ ] beta file created | `test -f /tmp/ralph-test-beta.txt`
- [ ] gamma file created | `test -f /tmp/ralph-test-gamma.txt`
- [ ] result file created | `test -f /tmp/ralph-test-result.txt`

## Errors

| Error | Task | Attempt | Resolution |
|-------|------|---------|------------|
