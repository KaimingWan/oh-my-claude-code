#!/usr/bin/env python3
"""generate_configs.py — Single source of truth for CC + Kiro agent configs.

Replaces generate-platform-configs.sh. Outputs:
  .claude/settings.json
  .kiro/agents/{pilot,reviewer,researcher,executor}.json
"""
import json
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent

# ── Shared hook definitions ──────────────────────────────────────────────

SECURITY_HOOKS_BASH = [
    {"matcher": "execute_bash", "command": "hooks/security/block-dangerous.sh"},
    {"matcher": "execute_bash", "command": "hooks/security/block-secrets.sh"},
    {"matcher": "execute_bash", "command": "hooks/security/block-sed-json.sh"},
    {"matcher": "execute_bash", "command": "hooks/security/block-outside-workspace.sh"},
    {"matcher": "fs_write", "command": "hooks/security/block-outside-workspace.sh"},
]

SECURITY_HOOKS_CLAUDE = [
    {"type": "command", "command": 'bash "$CLAUDE_PROJECT_DIR"/hooks/security/block-dangerous.sh'},
    {"type": "command", "command": 'bash "$CLAUDE_PROJECT_DIR"/hooks/security/block-secrets.sh'},
    {"type": "command", "command": 'bash "$CLAUDE_PROJECT_DIR"/hooks/security/block-sed-json.sh'},
    {"type": "command", "command": 'bash "$CLAUDE_PROJECT_DIR"/hooks/security/block-outside-workspace.sh'},
]

DENIED_COMMANDS_STRICT = [
    r"rm\s+(-[rRf]|--recursive|--force).*",
    r"rmdir\b.*", r"mkfs\b.*", r"sudo\b.*",
    r"git\s+push\s+.*--force.*", r"git\s+reset\s+--hard.*", r"git\s+clean\s+-f.*",
    r"chmod\s+(-R\s+)?777.*",
    r"curl.*\|\s*(ba)?sh.*", r"wget.*\|\s*(ba)?sh.*",
    r"kill\s+-9.*", r"killall\b.*", r"shutdown\b.*", r"reboot\b.*",
    r"DROP\s+(DATABASE|TABLE|SCHEMA).*", r"TRUNCATE\b.*",
    r"find\b.*-delete", r"find\b.*-exec\s+rm",
]

DENIED_COMMANDS_SUBAGENT = [
    "git commit.*", "git push.*", "git checkout.*", "git reset.*", "git stash.*",
]


# ── Config builders ──────────────────────────────────────────────────────

def claude_settings() -> dict:
    return {
        "permissions": {"allow": ["Bash(*)", "Read(*)", "Write(*)", "Edit(*)"], "deny": []},
        "hooks": {
            "UserPromptSubmit": [{"hooks": [
                {"type": "command", "command": 'bash "$CLAUDE_PROJECT_DIR"/hooks/feedback/correction-detect.sh'},
                {"type": "command", "command": 'bash "$CLAUDE_PROJECT_DIR"/hooks/feedback/session-init.sh'},
                {"type": "command", "command": 'bash "$CLAUDE_PROJECT_DIR"/hooks/feedback/context-enrichment.sh'},
            ]}],
            "PreToolUse": [
                {"matcher": "Bash", "hooks": SECURITY_HOOKS_CLAUDE},
                {"matcher": "Write|Edit", "hooks": [
                    {"type": "command", "command": 'bash "$CLAUDE_PROJECT_DIR"/hooks/security/block-outside-workspace.sh'},
                    {"type": "command", "command": 'bash "$CLAUDE_PROJECT_DIR"/hooks/gate/pre-write.sh'},
                ]},
            ],
            "PostToolUse": [
                {"matcher": "Write|Edit", "hooks": [
                    {"type": "command", "command": 'bash "$CLAUDE_PROJECT_DIR"/hooks/feedback/post-write.sh'},
                ]},
                {"matcher": "Bash", "hooks": [
                    {"type": "command", "command": 'bash "$CLAUDE_PROJECT_DIR"/hooks/feedback/post-bash.sh'},
                ]},
            ],
            "Stop": [{"hooks": [
                {"type": "command", "command": 'bash "$CLAUDE_PROJECT_DIR"/hooks/feedback/verify-completion.sh'},
            ]}],
        },
    }


def pilot_agent() -> dict:
    return {
        "name": "pilot",
        "description": "Main orchestrator agent with deterministic workflow gates",
        "tools": ["*"],
        "allowedTools": ["*"],
        "resources": [
            "file://AGENTS.md",
            "file://knowledge/INDEX.md",
            "skill://skills/**/SKILL.md",
        ],
        "hooks": {
            "userPromptSubmit": [
                {"command": "hooks/feedback/correction-detect.sh"},
                {"command": "hooks/feedback/session-init.sh"},
                {"command": "hooks/feedback/context-enrichment.sh"},
            ],
            "preToolUse": SECURITY_HOOKS_BASH + [
                {"matcher": "fs_write", "command": "hooks/gate/pre-write.sh"},
                {"matcher": "execute_bash", "command": "hooks/gate/enforce-ralph-loop.sh"},
                {"matcher": "fs_write", "command": "hooks/gate/enforce-ralph-loop.sh"},
                {"matcher": "execute_bash", "command": "hooks/gate/require-regression.sh"},
            ],
            "postToolUse": [
                {"matcher": "fs_write", "command": "hooks/feedback/post-write.sh"},
                {"matcher": "execute_bash", "command": "hooks/feedback/post-bash.sh"},
            ],
            "stop": [{"command": "hooks/feedback/verify-completion.sh"}],
        },
        "toolsSettings": {
            "subagent": {
                "availableAgents": ["researcher", "reviewer", "executor"],
                "trustedAgents": ["researcher", "reviewer", "executor"],
            },
            "shell": {
                "autoAllowReadonly": True,
                "deniedCommands": DENIED_COMMANDS_STRICT,
            },
        },
    }


def reviewer_agent() -> dict:
    return {
        "name": "reviewer",
        "description": "Review expert. Plan review: challenge decisions, find gaps. Code review: check quality, security, SOLID.",
        "prompt": "file://../../agents/reviewer-prompt.md",
        "tools": ["read", "write", "shell"],
        "allowedTools": ["read", "write", "shell"],
        "resources": ["file://AGENTS.md", "skill://skills/reviewing/SKILL.md"],
        "hooks": {
            "agentSpawn": [{"command": "echo '🔍 REVIEWER: Never skip analysis — always read the full plan/diff before giving verdict'"}],
            "preToolUse": SECURITY_HOOKS_BASH,
            "postToolUse": [{"matcher": "execute_bash", "command": "hooks/feedback/post-bash.sh"}],
            "stop": [{"command": "echo '📋 Review checklist: correctness, security, edge cases, test coverage?'"}],
        },
        "includeMcpJson": True,
        "toolsSettings": {
            "shell": {
                "autoAllowReadonly": True,
                "deniedCommands": ["git commit.*", "git push.*", "git checkout.*", "git reset.*"],
            },
        },
    }


def researcher_agent() -> dict:
    return {
        "name": "researcher",
        "description": "Research specialist. Web research via fetch MCP + code search via ripgrep MCP + Tavily via shell.",
        "prompt": "file://../../agents/researcher-prompt.md",
        "mcpServers": {
            "fetch": {"command": "uvx", "args": ["--with", "socksio", "mcp-server-fetch"]},
        },
        "tools": ["read", "shell", "@ripgrep", "@fetch"],
        "allowedTools": ["read", "shell", "@ripgrep", "@fetch"],
        "resources": ["file://AGENTS.md", "skill://skills/research/SKILL.md"],
        "hooks": {
            "agentSpawn": [{"command": "echo '🔬 RESEARCHER: 1) Cite sources 2) Cross-verify claims 3) Report gaps explicitly'"}],
            "preToolUse": SECURITY_HOOKS_BASH,
            "postToolUse": [{"matcher": "execute_bash", "command": "hooks/feedback/post-bash.sh"}],
            "stop": [{"command": "echo '📝 Research complete. Did you: cite sources, cross-verify, report gaps?'"}],
        },
        "includeMcpJson": True,
        "toolsSettings": {
            "shell": {
                "autoAllowReadonly": True,
                "deniedCommands": ["git commit.*", "git push.*"],
            },
        },
    }


def executor_agent() -> dict:
    return {
        "name": "executor",
        "description": "Task executor for parallel plan execution. Implements code + runs verify. Does NOT edit plan files or git commit.",
        "tools": ["read", "write", "shell"],
        "allowedTools": ["read", "write", "shell"],
        "hooks": {
            "agentSpawn": [{"command": "echo '⚡ EXECUTOR: 1) Implement assigned task 2) Run verify command 3) Report result 4) Do NOT git commit or edit plan files'"}],
            "preToolUse": SECURITY_HOOKS_BASH,
            "postToolUse": [{"matcher": "execute_bash", "command": "hooks/feedback/post-bash.sh"}],
        },
        "includeMcpJson": True,
        "toolsSettings": {
            "shell": {
                "autoAllowReadonly": True,
                "deniedCommands": DENIED_COMMANDS_SUBAGENT,
            },
        },
    }


# ── Write configs ────────────────────────────────────────────────────────

def write_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")


def main() -> int:
    print("🔧 Generating platform configs from unified source...")

    targets = [
        (PROJECT_ROOT / ".claude" / "settings.json", claude_settings()),
        (PROJECT_ROOT / ".kiro" / "agents" / "pilot.json", pilot_agent()),
        (PROJECT_ROOT / ".kiro" / "agents" / "reviewer.json", reviewer_agent()),
        (PROJECT_ROOT / ".kiro" / "agents" / "researcher.json", researcher_agent()),
        (PROJECT_ROOT / ".kiro" / "agents" / "executor.json", executor_agent()),
    ]

    errors = 0
    for path, data in targets:
        write_json(path, data)
        # Validate by re-reading
        try:
            json.loads(path.read_text())
            print(f"  ✅ {path.relative_to(PROJECT_ROOT)}")
        except json.JSONDecodeError:
            print(f"  ❌ INVALID JSON: {path.relative_to(PROJECT_ROOT)}")
            errors += 1

    if errors:
        print(f"\n❌ {errors} config(s) have invalid JSON!")
        return 1

    print("\n✅ All configs generated and validated.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
