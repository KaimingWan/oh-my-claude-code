# Reflect — Manual Knowledge Capture

Read the current conversation and identify insights worth preserving.

## Process
1. Ask user: "What insight should I capture?" (or user already stated it)
2. Extract: trigger scenario + DO/DON'T action + keywords
3. Check dedup: grep -iw keywords in knowledge/rules.md and knowledge/episodes.md
   - Already in rules → tell user, skip
   - Already in episodes → tell user count, suggest promotion if ≥3
4. Format: `DATE | active | KEYWORDS | SUMMARY` (≤80 chars, no | in summary)
5. Append to knowledge/episodes.md
6. Output: 📝 Captured → episodes.md: 'SUMMARY'

## Rules
- @reflect only writes to episodes.md (promotion to rules.md is done by self-reflect skill, not @reflect)
- Summary must contain actionable DO/DON'T, not narrative
- Keywords: 1-3 english technical terms, ≥4 chars each, comma-separated
- If episodes.md has ≥30 entries, warn user to clean up first
