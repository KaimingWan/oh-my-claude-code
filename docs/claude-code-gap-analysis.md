# Claude Code Gap Analysis

This document identifies all differences between Kiro CLI and Claude Code that affect the framework compatibility.

## Gap 1: Config format

| Field | Description | Impact | Fix Strategy | Status |
|-------|-------------|--------|--------------|--------|
| Description | Kiro uses `.kiro/agents/*.json`, CC uses `.claude/agents/*.md` with YAML frontmatter | High | Create config converter to transform between formats | Planned |
| Impact | Agent definitions incompatible between systems | High | | |
| Fix Strategy | Build bidirectional converter handling JSON↔YAML+Markdown | High | | |
| Status | Planned | High | | |

## Gap 2: Hook Stdin

| Field | Description | Impact | Fix Strategy | Status |
|-------|-------------|--------|--------------|--------|
| Description | Tool names differ: `execute_bash` vs `Bash`, `fs_write` vs `Write|Edit`; field names: `path` vs `file_path`, `file_text` vs `content`, `old_str`/`new_str` vs `old_string`/`new_string` | High | Create hook stdin translator | Planned |
| Impact | Hooks receive incompatible data structures | High | | |
| Fix Strategy | Map tool names and field names in hook input processing | High | | |
| Status | Planned | High | | |

## Gap 3: Hook Events

| Field | Description | Impact | Fix Strategy | Status |
|-------|-------------|--------|--------------|--------|
| Description | CC has additional events: `SessionStart`, `SubagentStart`, `SubagentStop`, `PostToolUseFailure`, `Notification`, `TeammateIdle`, `TaskCompleted`, `PreCompact`, `SessionEnd`. CC's `PermissionRequest` does NOT fire in `-p` mode | Medium | Add event mapping and filtering | Planned |
| Impact | Hooks may expect events that don't exist in target system | Medium | | |
| Fix Strategy | Create event compatibility layer with no-op handlers for missing events | Medium | | |
| Status | Planned | Medium | | |

## Gap 4: Subagent Format

| Field | Description | Impact | Fix Strategy | Status |
|-------|-------------|--------|--------------|--------|
| Description | Kiro: JSON with `tools`, `allowedTools`, `prompt: "file://..."`. CC: Markdown with YAML frontmatter, inline system prompt body, `tools:` as comma-separated list | High | Build subagent format converter | Planned |
| Impact | Subagent definitions incompatible | High | | |
| Fix Strategy | Convert between JSON and YAML+Markdown formats | High | | |
| Status | Planned | High | | |

## Gap 5: Skills Frontmatter

| Field | Description | Impact | Fix Strategy | Status |
|-------|-------------|--------|--------------|--------|
| Description | Kiro uses `skill://skills/**/SKILL.md` resource refs. CC loads from `.claude/skills/` or project root | Medium | Create skill path resolver | Planned |
| Impact | Skills may not load correctly | Medium | | |
| Fix Strategy | Map skill references between path formats | Medium | | |
| Status | Planned | Medium | | |

## Gap 6: Commands Mapping

| Field | Description | Impact | Fix Strategy | Status |
|-------|-------------|--------|--------------|--------|
| Description | Kiro: `kiro-cli chat --no-interactive`. CC: `claude -p`. Different arg formats | High | Auto-detect CLI and map commands | Planned |
| Impact | Scripts hardcoded to specific CLI won't work | High | | |
| Fix Strategy | Detect available CLI and translate command arguments | High | | |
| Status | Planned | High | | |

## Gap 7: Ralph Loop CLI

| Field | Description | Impact | Fix Strategy | Status |
|-------|-------------|--------|--------------|--------|
| Description | `ralph_loop.py` hardcoded to `kiro-cli`, needs auto-detection | Medium | Add CLI auto-detection to ralph_loop.py | Planned |
| Impact | Ralph loop only works with Kiro CLI | Medium | | |
| Fix Strategy | Detect available CLI (kiro-cli vs claude) and use appropriate commands | Medium | | |
| Status | Planned | Medium | | |

## Gap 8: $CLAUDE_PROJECT_DIR

| Field | Description | Impact | Fix Strategy | Status |
|-------|-------------|--------|--------------|--------|
| Description | CC hooks use this env var for paths. Kiro hooks use relative paths | Medium | Add environment variable handling | Planned |
| Impact | Path resolution may fail in hooks | Medium | | |
| Fix Strategy | Set/use $CLAUDE_PROJECT_DIR consistently or convert to relative paths | Medium | | |
| Status | Planned | Medium | | |

## Gap 9: stop_hook_active

| Field | Description | Impact | Fix Strategy | Status |
|-------|-------------|--------|--------------|--------|
| Description | CC sends `{"stop_hook_active": true}` to prevent infinite stop hook loops. Not handled in verify-completion.sh | Low | Add stop_hook_active handling | Planned |
| Impact | Potential infinite loops in stop hooks | Low | | |
| Fix Strategy | Check for stop_hook_active flag in verification scripts | Low | | |
| Status | Planned | Low | | |

## Gap 10: Tool Name Mapping

| Field | Description | Impact | Fix Strategy | Status |
|-------|-------------|--------|--------------|--------|
| Description | Full mapping: Bash↔execute_bash, Write↔fs_write(create), Edit↔fs_write(str_replace), Read↔fs_read, Glob↔glob, Grep↔grep, Task↔use_subagent, WebFetch↔web_fetch, WebSearch↔web_search | High | Create comprehensive tool name mapper | Planned |
| Impact | Tool usage incompatible between systems | High | | |
| Fix Strategy | Bidirectional tool name translation in all hook processing | High | | |
| Status | Planned | High | | |

## Gap 11: Hook Exit Codes

| Field | Description | Impact | Fix Strategy | Status |
|-------|-------------|--------|--------------|--------|
| Description | Same for both: 0=allow, 2=block. CC also supports JSON output with `hookSpecificOutput.permissionDecision` | Low | Add JSON output support | Planned |
| Impact | Limited hook response options | Low | | |
| Fix Strategy | Support both exit codes and JSON output formats | Low | | |
| Status | Planned | Low | | |

## Gap 12: macOS Compatibility

| Field | Description | Impact | Fix Strategy | Status |
|-------|-------------|--------|--------------|--------|
| Description | `timeout` not available on macOS, need `gtimeout` or `perl -e 'alarm'` fallback. `grep -P` not available, use `grep -E` | Medium | Add macOS compatibility layer | Planned |
| Impact | Scripts fail on macOS systems | Medium | | |
| Fix Strategy | Detect OS and use appropriate commands (gtimeout/perl for timeout, grep -E for regex) | Medium | | |
| Status | Planned | Medium | | |