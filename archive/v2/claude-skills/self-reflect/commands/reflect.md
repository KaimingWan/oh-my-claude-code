---
description: Review learnings queue and sync to 3-layer architecture
allowed-tools: Read, Write, Bash, Grep
---

## Context
- Queue: !`cat ~/.kiro/learnings-queue.json 2>/dev/null || echo "[]"`
- Project CLAUDE.md: @CLAUDE.md
- Architecture: @.kiro/rules/enforcement.md @.kiro/rules/reference.md

## Sync Targets

| Target | File | Rule Type |
|--------|------|-----------|
| Global | `~/.kiro/AGENTS.md` | Model selection, universal preferences |
| High-frequency | `./CLAUDE.md` or `./AGENTS.md` | Every-conversation rules |
| Enforcement | `.kiro/rules/enforcement.md` | Codifiable rules |
| Reference | `.kiro/rules/reference.md` | Low-frequency detailed rules |

## Task

1. Load queue from `~/.kiro/learnings-queue.json`
2. If empty, output "📭 No pending learnings." and stop
3. Display summary table with suggested targets
4. Ask user: [A]pply all / [R]eview each / [S]kip
5. Write learnings to target files
6. Clear processed items from queue
7. Confirm with summary
