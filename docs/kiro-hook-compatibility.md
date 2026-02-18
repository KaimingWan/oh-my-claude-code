# Dual-Platform Compatibility Matrix

> Generated from audit on 2026-02-17, expanded 2026-02-18 for Claude Code parity.
> See also: [Gap Analysis](claude-code-gap-analysis.md) | [CC Integration Tests](../tests/cc-integration/README.md)

## Event Support

| Event | Claude Code | Kiro CLI | Notes |
|-------|-------------|----------|-------|
| PreToolUse | ✅ | ✅ | Exit 2 = block |
| PostToolUse | ✅ | ✅ | Advisory only |
| userPromptSubmit | ✅ | ✅ | Receives `{"prompt":"..."}` |
| stop | ✅ | ✅ | Fires on turn end. CC sends `stop_hook_active` to prevent loops |
| agentSpawn | ❌ | ✅ | Kiro-only. Fires once when agent activates |

## Hook Compatibility

| # | Hook | CC | Kiro | Test Coverage | Notes |
|---|------|-----|------|---------------|-------|
| 1 | security/block-dangerous.sh | ✅ | ✅ | CC + Kiro | Handles both `Bash` and `execute_bash` tool names |
| 2 | security/block-secrets.sh | ✅ | ✅ | CC + Kiro | Handles both tool names |
| 3 | security/block-sed-json.sh | ✅ | ✅ | CC + Kiro | Handles both tool names |
| 4 | security/block-outside-workspace.sh | ✅ | ✅ | CC + Kiro | jq fallback: `.file_path // .path` |
| 5 | gate/pre-write.sh | ✅ | ✅ | CC + Kiro | Fixed: absolute path normalization for Kiro |
| 6 | gate/enforce-ralph-loop.sh | ✅ | ✅ | CC + Kiro | Handles both tool name sets |
| 7 | gate/require-regression.sh | ✅ | ✅ | CC + Kiro | Handles both `Bash` and `execute_bash` |
| 8 | feedback/correction-detect.sh | ✅ | ✅ | CC + Kiro | Parses `.prompt` from stdin |
| 9 | feedback/session-init.sh | ✅ | ✅ | CC + Kiro | Parses `.prompt` from stdin |
| 10 | feedback/context-enrichment.sh | ✅ | ✅ | CC + Kiro | Parses `.prompt` from stdin |
| 11 | feedback/post-write.sh | ✅ | ✅ | CC + Kiro | jq fallback: `.file_path // .path` |
| 12 | feedback/post-bash.sh | ✅ | ✅ | CC + Kiro | Handles both tool names |
| 13 | feedback/verify-completion.sh | ✅ | ✅ | CC + Kiro | Handles `stop_hook_active` (exits 0 immediately) |
| 14 | feedback/auto-capture.sh | ✅ | N/A | — | Not wired (called by correction-detect) |
| 15 | feedback/kb-health-report.sh | ✅ | N/A | — | Not wired (called by verify-completion) |

## Agent Config Format

| Aspect | Claude Code | Kiro CLI |
|--------|-------------|----------|
| Config location | `.claude/agents/*.md` | `.kiro/agents/*.json` |
| Format | YAML frontmatter + Markdown body | JSON |
| Tools field | `tools: Read, Write, Bash, Grep, Glob` | `"tools": ["read", "write", "shell"]` |
| Prompt | Inline Markdown body | `"prompt": "file://..."` |
| Hooks | YAML `hooks:` section in frontmatter | JSON `hooks` array |
| Generator | `scripts/generate_configs.py` | `scripts/generate_configs.py` |

## Ralph Loop CLI Detection

| Priority | CLI | Command Format |
|----------|-----|---------------|
| 1 (highest) | `RALPH_KIRO_CMD` env var | Custom override |
| 2 | `claude` (if authenticated) | `claude -p <prompt> --allowedTools Bash,Read,Write,Edit,Task,WebSearch,WebFetch --output-format text` |
| 3 | `kiro-cli` | `kiro-cli chat --no-interactive --trust-all-tools --agent pilot <prompt>` |

Detection logic: `scripts/lib/cli_detect.py` — checks `RALPH_KIRO_CMD` first, then probes `claude` auth, falls back to `kiro-cli`.

## Key Differences: Claude Code vs Kiro CLI

| Aspect | Claude Code | Kiro CLI |
|--------|-------------|----------|
| Tool names | `Bash`, `Write`, `Edit` | `execute_bash`, `fs_write` |
| fs_write path field | `file_path` | `path` |
| fs_write content field | `content` | `file_text` |
| Stdin common fields | `hook_event_name`, `cwd`, `session_id`, `transcript_path`, `permission_mode` | `hook_event_name`, `cwd` |
| Hook config | `"command":"bash \"$CLAUDE_PROJECT_DIR\"/hooks/..."` | `"command":"hooks/..."` |
| agentSpawn event | ❌ | ✅ |
| stop_hook_active | ✅ (prevents infinite stop loops) | ❌ |

## Test Suites

| Suite | Path | Platform | What It Tests |
|-------|------|----------|---------------|
| Kiro hook compat | `tests/hooks/test-kiro-compat.sh` | Kiro | All wired hooks with Kiro JSON format |
| CC hook compat | `tests/hooks/test-cc-compat.sh` | CC | All wired hooks with CC JSON format |
| CC integration | `tests/cc-integration/run.sh` | CC | End-to-end with `claude -p` (requires CC auth) |
| Ralph loop unit | `tests/ralph-loop/` | Both | CLI detection, plan parsing, scheduling, prompt building |

## Fixes Applied

1. **pre-write.sh absolute path normalization** — Kiro sends absolute paths in `tool_input.path`. Added `WORKSPACE` detection and `${FILE#$WORKSPACE/}` stripping.
2. **verify-completion.sh stop_hook_active** — CC sends `{"stop_hook_active": true}` on recursive stop. Added early exit to prevent infinite loops.

## Recommendations

1. **agentSpawn for session-init** — `session-init.sh` currently runs on `userPromptSubmit` with a flag-file guard. Adding it to `agentSpawn` would be cleaner. Low priority since current approach works.
2. **post-write.sh path normalization** — Should add the same absolute→relative normalization as pre-write.sh for consistency.
