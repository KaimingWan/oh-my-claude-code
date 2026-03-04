# Findings

## Codebase Patterns

- **build_prompt structure:** Single f-string return. New prompt sections append before the closing `"""`. All dynamic content uses f-string interpolation with variables computed above the return.
- **Test pattern:** Tests import `build_prompt` and `PlanFile` directly, create a minimal plan in `tmp_path`, call `build_prompt()`, and assert on string content. No subprocess needed for prompt tests.
- **Plan hook timing:** The verify-before-checkoff hook requires the verify command to be the most recent `execute_bash` call before the `str_replace` that marks `- [x]`. Running it earlier and doing other tool calls in between triggers the block.

- **Pre-existing test failures:** 4 tests in test_ralph_loop.py fail before any changes: test_detect_claude_cli, test_no_cli_found, test_parse_config_defaults, test_claude_cmd_has_no_session_persistence. All related to CLI detection and config defaults — likely from a recent kiro-cli migration that updated detect_cli behavior without updating tests.
