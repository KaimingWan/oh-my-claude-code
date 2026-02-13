# Security Rules

- Never pipe curl/wget output to shell
- Never commit secrets, API keys, or credentials
- Use environment variables for sensitive configuration
- Validate all external input before processing
- These rules are enforced by PreToolUse hooks — violations will be blocked automatically
