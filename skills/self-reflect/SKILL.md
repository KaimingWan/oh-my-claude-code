---
name: self-reflect
description: "Handles promotion of episodes to rules, and complex insight capture that auto-capture can't handle."
---

# Self-Reflect — Agent Self-Learning System

## Scope (v3)

1. **Promotion execution**: When hook outputs 🔥 or ⬆️, read episodes.md,
   distill into 1-2 line rule, propose to user, write to rules.md if approved.
   Mark source episodes as `promoted`.

2. **Complex insight capture**: When hook outputs 🚨 (complex) and the correction
   is too complex for auto-capture (no simple DO/DON'T pattern), help user
   articulate and write to episodes.md via the same format.

NOT responsible for: daily capture (hook does it), dedup (hook does it),
quality reporting (hook does it).

## Sync Targets

| Scenario | Target |
|----------|--------|
| Promotion (≥3 same pattern) | knowledge/rules.md (matching keyword section) |
| Complex insight | knowledge/episodes.md |
| Code-enforceable rule | .kiro/rules/enforcement.md |

## Episode Format

`DATE | STATUS | KEYWORDS | SUMMARY`

- DATE: YYYY-MM-DD
- STATUS: active / resolved / promoted
- KEYWORDS: 1-3 english technical terms, ≥4 chars, comma-separated
- SUMMARY: ≤80 chars, no `|` character, actionable DO/DON'T

## Promotion Process

1. Read episodes.md, find keywords appearing ≥3 times in active episodes
2. Distill into 1-2 line rule with DO/DON'T + trigger scenario
3. Read knowledge/rules.md section headers (`## [keywords]`)
4. **Clustering** — choose target section by semantic match:
   - Compare episode keywords with each section's keyword list
   - Pick the section with most keyword overlap + semantic relevance
   - If no section matches → create new `## [episode-keywords]` section at end of file
   - If placing in existing section → append new keywords to section header if they add value
5. Propose to user for approval (show target section)
6. If approved: append rule to chosen section, change source episodes status to `promoted`
7. Output: ⬆️ Promoted to rules.md [section]: 'RULE'

Note: promoted episodes are auto-cleaned by context-enrichment on next session start.

## Trigger Patterns

**High confidence (90%)**:
- `remember:` / `always:`
- `don't ... unless`
- `I told you`

**Medium confidence (80%)**:
- `no, use X` / `not X, use Y`
- `you missed` / `why didn't you`

### Exclusion Patterns (Don't capture)
- Questions ending with `?`
- Requests starting with `please` / `help me`
- Messages over 300 characters without clear DO/DON'T pattern

## On Detection

1. Confirm: `📝 Learning captured: '[preview]'`
2. **Write to target file immediately** (no queue)
3. Continue answering the user's question
