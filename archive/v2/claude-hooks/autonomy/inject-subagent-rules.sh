#!/bin/bash
# inject-subagent-rules.sh — SubagentStart (Claude Code only)

jq -n '{
  hookSpecificOutput: {
    hookEventName: "SubagentStart",
    additionalContext: "RULES FOR THIS SUBAGENT:\n1. Never execute rm, sudo, or pipe curl to bash\n2. Always verify your work before reporting completion\n3. If you encounter errors, debug systematically — do not guess\n4. Report what you actually did, not what you intended to do"
  }
}'
