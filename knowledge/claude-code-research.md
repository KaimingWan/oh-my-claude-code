# Claude Code Research Notes

> Findings from official docs research (2026-02-18). Source: code.claude.com/docs

## Authentication

- `claude auth status` → `{"loggedIn": false}` even when interactive `claude` works
- Interactive mode triggers OAuth on startup (needs browser)
- **Headless `-p` mode cannot trigger OAuth** → requires pre-existing auth or API key
- `ANTHROPIC_API_KEY` env var bypasses OAuth entirely (Claude Code detects it at init)
- SSH remote: use `ssh -L` port forwarding for OAuth, or set API key
- No `--no-open` flag exists for login
- Auth token location: `~/.config/claude-code/auth.json` (per GitHub issue #7100)

## Headless Mode (`claude -p`)

- `claude -p "prompt"` — non-interactive, prints response to stdout
- `--output-format text|json|stream-json`
- `--allowedTools "Bash,Read,Write,Edit,Task,WebSearch,WebFetch"` — auto-approve tools
- `--dangerously-skip-permissions` — skip ALL permission prompts
- `--max-turns N` — limit agentic turns (print mode only)
- `--max-budget-usd N` — spending cap
- `--model sonnet|opus` — model selection
- `--append-system-prompt "text"` — add to default system prompt
- `--agent my-agent` — use specific agent from `.claude/agents/`
- `--continue` / `--resume SESSION_ID` — continue conversations

## Hooks in Headless Mode

- **PreToolUse**: ✅ fires normally in `-p` mode
- **PostToolUse**: ✅ fires normally
- **Stop**: ✅ fires normally
- **UserPromptSubmit**: ✅ fires normally
- **PermissionRequest**: ❌ does NOT fire in `-p` mode (official docs explicit)
- **SessionStart**: ✅ fires normally
- All hooks run in parallel, identical commands deduplicated

## Hook Input/Output

### Common input fields (ALL events)
- `session_id`, `transcript_path`, `cwd`, `permission_mode`, `hook_event_name`

### Tool names (CC vs Kiro)
| CC | Kiro |
|----|------|
| `Bash` | `execute_bash` |
| `Write` | `fs_write` (command=create) |
| `Edit` | `fs_write` (command=str_replace) |
| `Read` | `fs_read` |
| `Glob` | `glob` |
| `Grep` | `grep` |
| `Task` | `use_subagent` |
| `WebFetch` | `web_fetch` |
| `WebSearch` | `web_search` |

### Write tool_input fields
- CC Write: `file_path`, `content`
- CC Edit: `file_path`, `old_string`, `new_string`, `replace_all`
- Kiro fs_write: `path`, `file_text` (create), `old_str`, `new_str` (str_replace)

### Bash tool_input
- Both: `command` field
- CC adds: `description`, `timeout`, `run_in_background`

### Exit codes
- 0: allow (stdout parsed for JSON)
- 2: block (stderr fed back to Claude)
- Other: non-blocking error (stderr logged)

### PreToolUse JSON output (preferred over exit code 2)
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow|deny|ask",
    "permissionDecisionReason": "reason"
  }
}
```

### Stop hook
- `stop_hook_active: true` in input when already continuing from a stop hook
- Must check this to prevent infinite loops
- Decision: `{"decision": "block", "reason": "..."}`

## CC Agent Format (.claude/agents/*.md)

```markdown
---
name: agent-name
description: What this agent does
tools: Read, Write, Bash, Grep, Glob
model: inherit
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "\"$CLAUDE_PROJECT_DIR\"/hooks/security/block-dangerous.sh"
---

[System prompt markdown body here]
```

## CC Settings Format (.claude/settings.json)

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {"type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR\"/hooks/..."}
        ]
      }
    ]
  }
}
```

## Hook Events (full list)
SessionStart, UserPromptSubmit, PreToolUse, PermissionRequest, PostToolUse,
PostToolUseFailure, Notification, SubagentStart, SubagentStop, Stop,
TeammateIdle, TaskCompleted, PreCompact, SessionEnd

## macOS Compatibility
- `timeout` command does NOT exist on macOS
- Use `gtimeout` (from coreutils: `brew install coreutils`) or `perl -e 'alarm(N); exec @ARGV'`
- `grep -P` (Perl regex) not available on macOS, use `grep -E` instead

## Existing Hook Compatibility (already done)
- All hooks already have dual tool_name matching: `execute_bash|Bash`, `fs_write|Write|Edit`
- File path extraction: `.tool_input.file_path // .tool_input.path` (covers both)
- Content extraction: `.tool_input.content // .tool_input.file_text // .tool_input.new_str`
- Command extraction: `.tool_input.command` (same for both)

## Known Gaps (to fix in plan)
1. `stop_hook_active` not checked in verify-completion.sh
2. No `.claude/agents/*.md` files generated
3. `ralph_loop.py` hardcoded to `kiro-cli`
4. `require-regression.sh` not tested in test-kiro-compat.sh
5. No CC-format hook tests exist
