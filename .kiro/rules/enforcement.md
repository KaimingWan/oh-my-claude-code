# Enforcement Layer (v2)

> If it can be enforced by code, don't enforce it with words.

## Hook Registry

| Rule | Hook Path | Event | Type |
|------|-----------|-------|------|
| Context enrichment (replaces 3 Iron Rules + skill chain) | `.claude/hooks/autonomy/context-enrichment.sh` | userPromptSubmit | inject |
| Dangerous command blocker | `.claude/hooks/security/block-dangerous-commands.sh` | preToolUse[bash] | block |
| Secret leak blocker | `.claude/hooks/security/block-secrets.sh` | preToolUse[bash] | block |
| Skill chain (plan required for new files) | `.claude/hooks/quality/enforce-skill-chain.sh` | preToolUse[write] | block |
| Prompt injection scanner | `.claude/hooks/security/scan-skill-injection.sh` | preToolUse[write] | block |
| Auto-test after write | `.claude/hooks/quality/auto-test.sh` | postToolUse[write] | feedback |
| Auto-lint after write | `.claude/hooks/quality/auto-lint.sh` | postToolUse[write] | async |
| Completion verification (B+A+C) | `.claude/hooks/quality/verify-completion.sh` | stop | feedback |
| Reviewer stop check | `.claude/hooks/quality/reviewer-stop-check.sh` | stop (reviewer) | feedback |

## CC-Only Hooks

| Rule | Hook Path | Event |
|------|-----------|-------|
| Auto-approve safe commands | `.claude/hooks/autonomy/auto-approve-safe.sh` | PermissionRequest |
| Inject subagent rules | `.claude/hooks/autonomy/inject-subagent-rules.sh` | SubagentStart |
| Enforce tests on completion | `.claude/hooks/quality/enforce-tests.sh` | TaskCompleted |
| Session init | `.claude/hooks/lifecycle/session-init.sh` | SessionStart |
| Session cleanup | `.claude/hooks/lifecycle/session-cleanup.sh` | SessionEnd |
