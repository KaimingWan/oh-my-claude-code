---
name: reviewing
description: "Code and plan review — covers requesting, executing, and receiving reviews."
---

# Reviewing — Request, Execute, Receive

## Requesting Review

**When (mandatory):** after completing major feature, before merge, after each task batch.

Dispatch reviewer subagent with:
- What was implemented
- Plan/requirements reference
- Git diff range (BASE_SHA..HEAD_SHA)

## Executing Review (for reviewer agent)

### Plan Review Mode
1. Read plan completely
2. Challenge every decision: "What if X fails?" / "Why not Y?" / "What's missing?"
3. Play devil's advocate
4. Output: Strengths / Weaknesses / Missing / Verdict (APPROVE or REQUEST CHANGES)

### Code Review Mode
1. Run `git diff --stat` then `git diff`
2. Categorize: P0 Critical / P1 High / P2 Medium / P3 Low
3. Check: correctness, security, SOLID, test coverage, edge cases
4. Be specific — cite file:line, show code examples
5. Never rubber-stamp

## Receiving Review

**Core principle:** Verify before implementing. Technical correctness over social comfort.

1. READ complete feedback without reacting
2. UNDERSTAND — restate requirement (or ask)
3. VERIFY against codebase reality
4. EVALUATE — technically sound for THIS codebase?
5. RESPOND — technical acknowledgment or reasoned pushback
6. IMPLEMENT one item at a time, test each

**If feedback is unclear:** STOP. Ask for clarification on ALL unclear items before implementing any.

**Push back when reviewer is wrong** — with technical reasoning and evidence.

**Never:** "You're absolutely right!" / "Great point!" / implement before verifying.
