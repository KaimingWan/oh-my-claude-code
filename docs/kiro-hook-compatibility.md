# Kiro CLI Hook Compatibility Matrix

> Generated from audit on 2026-02-17. See `docs/plans/2026-02-17-kiro-hook-compatibility-audit.md`.

## Event Support

| Event | Claude Code | Kiro CLI | Notes |
|-------|-------------|----------|-------|
| PreToolUse | ✅ | ✅ | Exit 2 = block. Matcher uses `execute_bash`, `fs_write` |
| PostToolUse | ✅ | ✅ | Advisory only |
| userPromptSubmit | ✅ | ✅ | Receives `{"prompt":"..."}` |
| stop | ✅ | ✅ | Fires on turn end |
| agentSpawn | ❌ | ✅ | Kiro-only. Fires once when agent activates |

## Hook Compatibility

| # | Hook | CC | Kiro | Kiro Live Test | Notes |
|---|------|-----|------|----------------|-------|
| 1 | security/block-dangerous.sh | ✅ | ✅ | ✅ Block + Allow | Handles both `Bash` and `execute_bash` tool names |
| 2 | security/block-secrets.sh | ✅ | ✅ | ✅ Block + Allow | Handles both tool names |
| 3 | security/block-sed-json.sh | ✅ | ✅ | ✅ Block + Allow | Handles both tool names |
| 4 | security/block-outside-workspace.sh | ✅ | ✅ | ✅ Block + Allow | Handles `fs_write`/`Write`/`Edit` + `execute_bash`/`Bash`. jq fallback: `.file_path // .path` |
| 5 | gate/pre-write.sh | ✅ | ✅ | ✅ Block + Allow | Fixed: absolute path normalization for Kiro. jq fallback: `.file_path // .path`, `.content // .file_text // .new_str` |
| 6 | gate/enforce-ralph-loop.sh | ✅ | ✅ | ✅ Allow (no plan) | Handles both tool name sets. Path normalization already present |
| 7 | feedback/correction-detect.sh | ✅ | ✅ | ✅ Exit 0 | Parses `.prompt` from stdin |
| 8 | feedback/session-init.sh | ✅ | ✅ | ✅ Exit 0 | Parses `.prompt` from stdin. Consider agentSpawn for one-time init |
| 9 | feedback/context-enrichment.sh | ✅ | ✅ | ✅ Exit 0 | Parses `.prompt` from stdin |
| 10 | feedback/post-write.sh | ✅ | ✅ | ✅ Exit 0 | jq fallback: `.file_path // .path` |
| 11 | feedback/post-bash.sh | ✅ | ✅ | ✅ Exit 0 | Handles both tool names |
| 12 | feedback/verify-completion.sh | ✅ | ✅ | ✅ Exit 0 | Stop hook, no tool_name parsing |
| 13 | feedback/auto-capture.sh | ✅ | N/A | — | Not wired (called by correction-detect) |
| 14 | feedback/kb-health-report.sh | ✅ | N/A | — | Not wired (called by verify-completion) |

## Key Differences: Claude Code vs Kiro CLI

| Aspect | Claude Code | Kiro CLI |
|--------|-------------|----------|
| Tool names | `Bash`, `Write`, `Edit` | `execute_bash`, `fs_write` |
| fs_write path field | `file_path` | `path` |
| fs_write content field | `content` | `file_text` |
| Stdin JSON | `{"tool_name":"...","tool_input":{...}}` | Adds `hook_event_name`, `cwd` |
| Hook config | `"command":"bash \"$CLAUDE_PROJECT_DIR\"/hooks/..."` | `"command":"hooks/..."` |
| agentSpawn event | ❌ | ✅ |

## Fixes Applied During Audit

1. **pre-write.sh absolute path normalization** — Kiro sends absolute paths in `tool_input.path`. Added `WORKSPACE` detection and `${FILE#$WORKSPACE/}` stripping so instruction guard and other path-based checks work correctly.

## Recommendations

1. **agentSpawn for session-init** — `session-init.sh` currently runs on `userPromptSubmit` with a flag-file guard. Adding it to `agentSpawn` would be cleaner (guaranteed once, no flag file needed). Low priority since current approach works.
2. **post-write.sh path normalization** — Should add the same absolute→relative normalization as pre-write.sh for consistency, though current usage doesn't depend on relative paths.
