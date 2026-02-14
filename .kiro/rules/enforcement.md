# Enforcement Layer (v3)

> If it can be enforced by code, don't enforce it with words.

## Hook Registry

| Rule | Hook Path | Event | Type |
|------|-----------|-------|------|
| Dangerous command blocker | `hooks/security/block-dangerous.sh` | preToolUse[bash] | block |
| Secret leak blocker | `hooks/security/block-secrets.sh` | preToolUse[bash] | block |
| sed/awk on JSON blocker | `hooks/security/block-sed-json.sh` | preToolUse[bash] | block |
| Pre-write gate (workflow + injection scan + plan context) | `hooks/gate/pre-write.sh` | preToolUse[write] | block + inject |
| Post-write feedback (lint + test + progress remind) | `hooks/feedback/post-write.sh` | postToolUse[write] | feedback |
| Context enrichment (correction + lessons) | `hooks/feedback/context-enrichment.sh` | userPromptSubmit | inject |
| Completion verification | `hooks/feedback/verify-completion.sh` | stop | feedback |

## Determinism Layers

| Layer | Mechanism | Certainty |
|-------|-----------|-----------|
| L1 Commands | `@plan` `@execute` `@debug` `@research` `@review` | 100% — user triggers |
| L2 Gate | `hooks/gate/pre-write.sh` (exit 2 = block) | 100% — hard block |
| L2 Security | `hooks/security/*` (exit 2 = block) | 100% — hard block |
| L3 Feedback | `hooks/feedback/*` (exit 0 = info only) | ~50% — advisory |

## Config Generation

Single source: `scripts/generate-platform-configs.sh`
Generates: `.claude/settings.json` + `.kiro/agents/*.json`
