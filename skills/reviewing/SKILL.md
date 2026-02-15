---
name: reviewing
description: "Code review — covers requesting, executing, and receiving code reviews."
---

# Reviewing — Request, Execute, Receive

## Requesting Review

**When (mandatory):** after completing major feature, before merge, after each task batch.

Dispatch reviewer subagent with:
- What was implemented
- Plan/requirements reference
- Git diff range (BASE_SHA..HEAD_SHA)

## Executing Code Review (for reviewer agent)

### 1) Preflight context

- Run `git diff --stat` then `git diff` to understand scope
- If diff > 500 lines, batch by file/module — review each batch separately
- Note: file renames, new files, deleted files

### 2) SOLID + architecture check

- Load `references/solid-checklist.md` for coverage
- Check SRP, OCP, LSP, ISP, DIP violations
- Flag common code smells: long methods, feature envy, data clumps, dead code
- Apply refactor heuristics where applicable

### 3) Security scan

- Load `references/security-checklist.md` for coverage
- Check: input/output safety (XSS, injection, SSRF, path traversal), auth gaps, secrets in code
- Check: race conditions (concurrent access, check-then-act, TOCTOU, missing locks)
- Call out both **exploitability** and **impact**

### 4) Code quality scan

- Load `references/code-quality-checklist.md` for coverage
- Check: error handling (swallowed exceptions, overly broad catch, async errors)
- Check: performance (N+1 queries, CPU-intensive ops in hot paths, missing cache, unbounded memory)
- Check: boundary conditions (null/undefined, empty collections, numeric boundaries, off-by-one)
- Flag issues that may cause silent failures or production incidents

### 5) Removal candidates

- Load `references/removal-plan.md` for template
- Identify dead code, unused imports, deprecated patterns
- Categorize: safe to remove now vs defer with plan

### 6) Output

- Load `references/output-format.md` for structure
- Categorize findings: P0 Critical / P1 High / P2 Medium / P3 Low
- Be specific — cite file:line, show code examples
- Never rubber-stamp

### 7) Next steps confirmation

- Present findings summary with issue counts by priority
- Ask user how to proceed (fix all / P0-P1 only / specific items / no changes)
- Do NOT implement changes until user explicitly confirms

## Receiving Review

**Core principle:** Verify before implementing. Technical correctness over social comfort.

1. READ complete feedback without reacting
2. UNDERSTAND — restate requirement (or ask)
3. VERIFY against codebase reality
4. EVALUATE — technically sound for THIS codebase?
5. RESPOND — technical acknowledgment or reasoned pushback
6. IMPLEMENT one item at a time, test each

### YAGNI Check

Before implementing any suggestion, ask: "Does this solve a real problem we have now?" Reject speculative generality, premature abstractions, and features for hypothetical future needs.

### Implementation Order

When implementing accepted feedback:
1. **Blocking issues first** — anything that breaks build/tests
2. **Simple fixes** — typos, naming, formatting (quick wins)
3. **Complex changes** — refactors, architecture changes (highest risk, do last)

### Push Back

Push back when reviewer is wrong — with technical reasoning and evidence. Show code, show tests, show docs.

### Acknowledging Correct Feedback

When feedback is correct, acknowledge briefly and implement: "Agreed, fixing." No flattery.

**Never:** "You're absolutely right!" / "Great point!" / implement before verifying.
