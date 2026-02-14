#!/bin/bash
# generate-platform-configs.sh — Single source of truth for CC + Kiro configs
# Reads hooks/, agents/, commands/ and generates platform-specific JSON configs.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

echo "🔧 Generating platform configs from unified source..."

# ===== 1. Generate .claude/settings.json =====
mkdir -p .claude

jq -n '{
  permissions: {allow: ["Bash(*)", "Read(*)", "Write(*)", "Edit(*)"], deny: []},
  hooks: {
    UserPromptSubmit: [{
      hooks: [{type: "command", command: "bash \"$CLAUDE_PROJECT_DIR\"/hooks/feedback/context-enrichment.sh"}]
    }],
    PreToolUse: [
      {
        matcher: "Bash",
        hooks: [
          {type: "command", command: "bash \"$CLAUDE_PROJECT_DIR\"/hooks/security/block-dangerous.sh"},
          {type: "command", command: "bash \"$CLAUDE_PROJECT_DIR\"/hooks/security/block-secrets.sh"},
          {type: "command", command: "bash \"$CLAUDE_PROJECT_DIR\"/hooks/security/block-sed-json.sh"}
        ]
      },
      {
        matcher: "Write|Edit",
        hooks: [
          {type: "command", command: "bash \"$CLAUDE_PROJECT_DIR\"/hooks/gate/require-workflow.sh"},
          {type: "command", command: "bash \"$CLAUDE_PROJECT_DIR\"/hooks/security/scan-skill-injection.sh"}
        ]
      }
    ],
    PostToolUse: [{
      matcher: "Write|Edit",
      hooks: [
        {type: "command", command: "bash \"$CLAUDE_PROJECT_DIR\"/hooks/feedback/auto-test.sh"},
        {type: "command", command: "bash \"$CLAUDE_PROJECT_DIR\"/hooks/feedback/auto-lint.sh"}
      ]
    }],
    Stop: [{
      hooks: [{type: "command", command: "bash \"$CLAUDE_PROJECT_DIR\"/hooks/feedback/verify-completion.sh"}]
    }]
  }
}' > .claude/settings.json

echo "  ✅ .claude/settings.json"

# ===== 2. Generate .kiro/agents/*.json =====
mkdir -p .kiro/agents

# --- default agent ---
jq -n '{
  name: "default",
  description: "Main orchestrator agent with deterministic workflow gates",
  tools: ["*"],
  allowedTools: ["*"],
  resources: [
    "file://AGENTS.md",
    "file://knowledge/INDEX.md",
    "skill://skills/**/SKILL.md"
  ],
  hooks: {
    userPromptSubmit: [{command: "hooks/feedback/context-enrichment.sh"}],
    preToolUse: [
      {matcher: "execute_bash", command: "hooks/security/block-dangerous.sh"},
      {matcher: "execute_bash", command: "hooks/security/block-secrets.sh"},
      {matcher: "execute_bash", command: "hooks/security/block-sed-json.sh"},
      {matcher: "fs_write", command: "hooks/gate/require-workflow.sh"},
      {matcher: "fs_write", command: "hooks/security/scan-skill-injection.sh"}
    ],
    postToolUse: [
      {matcher: "fs_write", command: "hooks/feedback/auto-test.sh"},
      {matcher: "fs_write", command: "hooks/feedback/auto-lint.sh"}
    ],
    stop: [{command: "hooks/feedback/verify-completion.sh"}]
  },
  toolsSettings: {
    subagent: {
      availableAgents: ["researcher", "implementer", "reviewer", "debugger"],
      trustedAgents: ["researcher", "implementer", "reviewer", "debugger"]
    },
    shell: {
      autoAllowReadonly: true,
      deniedCommands: [
        "rm\\s+(-[rRf]|--recursive|--force).*",
        "rmdir\\b.*",
        "mkfs\\b.*",
        "sudo\\b.*",
        "git\\s+push\\s+.*--force.*",
        "git\\s+reset\\s+--hard.*",
        "git\\s+clean\\s+-f.*",
        "chmod\\s+(-R\\s+)?777.*",
        "curl.*\\|\\s*(ba)?sh.*",
        "wget.*\\|\\s*(ba)?sh.*",
        "kill\\s+-9.*",
        "killall\\b.*",
        "shutdown\\b.*",
        "reboot\\b.*",
        "DROP\\s+(DATABASE|TABLE|SCHEMA).*",
        "TRUNCATE\\b.*",
        "find\\b.*-delete",
        "find\\b.*-exec\\s+rm"
      ]
    }
  }
}' > .kiro/agents/default.json

echo "  ✅ .kiro/agents/default.json"

# --- reviewer agent ---
jq -n '{
  name: "reviewer",
  description: "Review expert. Plan review: challenge decisions, find gaps. Code review: check quality, security, SOLID. Read-only.",
  prompt: "file://../../agents/reviewer-prompt.md",
  tools: ["read", "shell"],
  allowedTools: ["read", "shell"],
  resources: [
    "file://AGENTS.md",
    "skill://skills/reviewing/SKILL.md"
  ],
  hooks: {
    agentSpawn: [{command: "echo '\''🔍 REVIEWER: 1) Run git diff first 2) Categorize: Critical/Warning/Suggestion 3) Be specific 4) Never rubber-stamp'\''"}],
    preToolUse: [{matcher: "execute_bash", command: "hooks/security/block-dangerous.sh"}],
    stop: [{command: "echo '\''📋 Review checklist: correctness, security, edge cases, test coverage?'\''"}]
  },
  toolsSettings: {
    shell: {
      autoAllowReadonly: true,
      deniedCommands: ["git commit.*", "git push.*", "git checkout.*", "git reset.*"]
    }
  }
}' > .kiro/agents/reviewer.json

echo "  ✅ .kiro/agents/reviewer.json"

# --- implementer agent ---
jq -n '{
  name: "implementer",
  description: "Implementation specialist. TDD, coding, feature implementation.",
  prompt: "file://../../agents/implementer-prompt.md",
  tools: ["read", "write", "shell"],
  allowedTools: ["read", "write", "shell"],
  resources: [
    "file://AGENTS.md",
    "skill://skills/planning/SKILL.md",
    "skill://skills/verification/SKILL.md"
  ],
  hooks: {
    agentSpawn: [{command: "echo '\''🔧 IMPLEMENTER: 1) Write tests first 2) Run tests after every change 3) Commit when tests pass'\''"}],
    preToolUse: [{matcher: "execute_bash", command: "hooks/security/block-dangerous.sh"}],
    postToolUse: [{matcher: "fs_write", command: "hooks/feedback/auto-test.sh"}],
    stop: [{command: "hooks/feedback/verify-completion.sh"}]
  },
  toolsSettings: {
    shell: {
      autoAllowReadonly: true,
      deniedCommands: ["rm\\s+(-[rRf]|--recursive|--force).*", "git\\s+push\\s+.*--force.*", "git\\s+reset\\s+--hard.*"]
    }
  }
}' > .kiro/agents/implementer.json

echo "  ✅ .kiro/agents/implementer.json"

# --- debugger agent ---
jq -n '{
  name: "debugger",
  description: "Systematic debugging specialist. Reproduce → hypothesize → verify → fix.",
  prompt: "file://../../agents/debugger-prompt.md",
  tools: ["read", "write", "shell"],
  allowedTools: ["read", "write", "shell"],
  resources: [
    "file://AGENTS.md",
    "skill://skills/debugging/SKILL.md",
    "file://knowledge/lessons-learned.md"
  ],
  hooks: {
    agentSpawn: [{command: "echo '\''🐛 DEBUGGER: 1) Reproduce first 2) Form hypothesis 3) Verify with evidence 4) Check lessons-learned'\''"}],
    preToolUse: [{matcher: "execute_bash", command: "hooks/security/block-dangerous.sh"}],
    stop: [{command: "hooks/feedback/verify-completion.sh"}]
  },
  toolsSettings: {
    shell: {
      autoAllowReadonly: true,
      deniedCommands: ["rm\\s+(-[rRf]|--recursive|--force).*", "git\\s+reset\\s+--hard.*"]
    }
  }
}' > .kiro/agents/debugger.json

echo "  ✅ .kiro/agents/debugger.json"

# --- researcher agent ---
jq -n '{
  name: "researcher",
  description: "Research specialist. Codebase exploration, web search, structured findings.",
  prompt: "file://../../agents/researcher-prompt.md",
  tools: ["read", "shell"],
  allowedTools: ["read", "shell"],
  resources: [
    "file://AGENTS.md",
    "skill://skills/research/SKILL.md"
  ],
  hooks: {
    agentSpawn: [{command: "echo '\''🔬 RESEARCHER: 1) Cite sources 2) Cross-verify claims 3) Report gaps explicitly'\''"}],
    stop: [{command: "echo '\''📝 Research complete. Did you: cite sources, cross-verify, report gaps?'\''"}]
  },
  toolsSettings: {
    shell: {
      autoAllowReadonly: true,
      deniedCommands: ["git commit.*", "git push.*"]
    }
  }
}' > .kiro/agents/researcher.json

echo "  ✅ .kiro/agents/researcher.json"

# ===== 3. Validate all generated JSON =====
ERRORS=0
for f in .claude/settings.json .kiro/agents/*.json; do
  if ! jq . "$f" > /dev/null 2>&1; then
    echo "  ❌ INVALID JSON: $f"
    ERRORS=$((ERRORS + 1))
  fi
done

if [ "$ERRORS" -eq 0 ]; then
  echo ""
  echo "✅ All configs generated and validated."
else
  echo ""
  echo "❌ $ERRORS config(s) have invalid JSON!"
  exit 1
fi
