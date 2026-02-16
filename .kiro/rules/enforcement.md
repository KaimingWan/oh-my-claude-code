# Enforcement Layer (v3)

> If it can be enforced by code, don't enforce it with words.

## Hook Registry

| Rule | Hook Path | Event | Type |
|------|-----------|-------|------|
| Dangerous command blocker | `hooks/security/block-dangerous.sh` | preToolUse[bash] | block |
| Secret leak blocker | `hooks/security/block-secrets.sh` | preToolUse[bash] | block |
| sed/awk on JSON blocker | `hooks/security/block-sed-json.sh` | preToolUse[bash] | block |
| Workspace boundary | `hooks/security/block-outside-workspace.sh` | preToolUse[bash,write] | block |
| Instruction file guard | `hooks/gate/pre-write.sh` (gate_instruction_files) | preToolUse[write] | block |
| Brainstorming gate | `hooks/gate/pre-write.sh` (gate_brainstorm) | preToolUse[write] | block |
| Pre-write gate (workflow + injection scan + plan context) | `hooks/gate/pre-write.sh` | preToolUse[write] | block + inject |
| Post-write feedback (lint + test + progress remind) | `hooks/feedback/post-write.sh` | postToolUse[write] | feedback |
| Correction detection | `hooks/feedback/correction-detect.sh` | userPromptSubmit | inject |
| Session init (rules + cleanup) | `hooks/feedback/session-init.sh` | userPromptSubmit | inject |
| Context enrichment (research + resume) | `hooks/feedback/context-enrichment.sh` | userPromptSubmit | inject |
| Bash execution log | `hooks/feedback/post-bash.sh` | postToolUse[bash] | feedback |
| Completion verification | `hooks/feedback/verify-completion.sh` | stop | feedback |

## Determinism Layers

| Layer | Mechanism | Certainty |
|-------|-----------|-----------|
| L1 Commands | `@plan` `@execute` `@research` `@review` `@reflect` | 100% — user triggers |
| L2 Gate | `hooks/gate/pre-write.sh` (exit 2 = block) | 100% — hard block |
| L2 Security | `hooks/security/*` (exit 2 = block) | 100% — hard block |
| L3 Feedback | `hooks/feedback/*` (exit 0 = info only) | ~50% — advisory |

## Config Generation

Single source: `scripts/generate_configs.py`
Generates: `.claude/settings.json` + `.kiro/agents/*.json`
