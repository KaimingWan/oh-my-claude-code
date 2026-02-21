# Custom Commands

## @lint — Health Check

When user says `@lint`, run instruction health check:

```bash
wc -l CLAUDE.md  # or AGENTS.md
grep -n "don't\|must\|never\|always\|禁止\|必须" CLAUDE.md
```

Output health report:
- Current line count / 200 line budget
- Rules that could be enforced by code
- Suggestions to migrate to enforcement.md

## @compact — Compress Instructions

Trigger compression workflow:
1. Identify low-frequency rules → Move to reference.md
2. Identify code-enforceable rules → Create enforcement
3. Merge duplicate rules
4. Tighten wording

## Review Checklist (Before Adding to Layer 2)

| Check | Question | If Yes → |
|-------|----------|----------|
| **Code-enforceable** | Can this be a linter/test/hook? | Write code, not prose |
| **High-frequency** | Needed every conversation? | Add to Layer 2 |
| **Not duplicate** | Already covered? | Merge or update |
| **Verifiable** | How to check compliance? | Define verification |
| **Concise** | Can it be shorter? | Tighten first |

## Language Matching

Agent 必须使用与用户相同的语言回复。用户用中文就回中文，用英文就回英文。
