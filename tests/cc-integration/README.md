# Claude Code Integration Tests

## Prerequisites

- Claude Code CLI installed (`claude` in PATH)
- Authenticated: `claude auth login` or `ANTHROPIC_API_KEY` env var set
- macOS: `brew install coreutils` for `gtimeout` (optional, perl fallback available)

## Run

```bash
bash tests/cc-integration/run.sh
```

## Behavior

- If `claude` not in PATH → all tests SKIP (exit 0)
- If not authenticated → all tests SKIP (exit 0)
- Each test has 120s timeout
- Tests verify hooks, skills, subagents, knowledge, and plan workflow via `claude -p`
