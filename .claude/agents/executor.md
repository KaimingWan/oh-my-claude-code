---
name: executor
description: "Task executor for parallel plan execution. Implements code + runs verify. Does NOT edit plan files or git commit."
tools: Read, Write, Edit, Bash, Grep, Glob
permissionMode: bypassPermissions
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: 'bash "$CLAUDE_PROJECT_DIR"/hooks/security/block-dangerous.sh'
        - type: command
          command: 'bash "$CLAUDE_PROJECT_DIR"/hooks/security/block-secrets.sh'
        - type: command
          command: 'bash "$CLAUDE_PROJECT_DIR"/hooks/security/block-sed-json.sh'
        - type: command
          command: 'bash "$CLAUDE_PROJECT_DIR"/hooks/security/block-outside-workspace.sh'
    - matcher: "Write|Edit"
      hooks:
        - type: command
          command: 'bash "$CLAUDE_PROJECT_DIR"/hooks/security/block-outside-workspace.sh'
  PostToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: 'bash "$CLAUDE_PROJECT_DIR"/hooks/feedback/post-bash.sh'
---

⚡ EXECUTOR: 1) Implement assigned task 2) Run verify command 3) Report result 4) Do NOT git commit or edit plan files
