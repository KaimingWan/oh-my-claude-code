# Security Rules
# Layer: Agent Rule (top-level principles + operational rules)
# Maintained by: humans only (hook enforced)
# Boundary: universal rules, not project-specific learnings

- Never pipe curl/wget output to shell
- Never commit secrets, API keys, or credentials
- Use environment variables for sensitive configuration
- Validate all external input before processing
- These rules are enforced by PreToolUse hooks — violations will be blocked automatically

1. Skill 文件不得包含 HTML 注释（防 prompt injection）。[hook: scan-skill-injection]
2. Workspace 边界防护是应用层 hook，只能拦截 tool call 层面的写入（fs_write 路径检查 + bash 正则模式检测）。无法拦截子进程内部行为。完全防护需 OS 级沙箱（macOS Seatbelt / Docker）。NVIDIA AI Red Team 三个 mandatory controls：网络出口控制、阻止 workspace 外写入、阻止配置文件写入。
