import pytest
from pathlib import Path

class TestDebuggingRules:
    def test_claude_rules_has_lsp(self):
        r = Path(".claude/rules/debugging.md").read_text()
        assert "get_diagnostics" in r
        assert "goto_definition" in r or "search_symbols" in r

    def test_claude_rules_has_evidence(self):
        r = Path(".claude/rules/debugging.md").read_text()
        assert "evidence" in r.lower() or "证据" in r

    def test_claude_rules_has_lsp_priority(self):
        r = Path(".claude/rules/debugging.md").read_text()
        assert "LSP" in r or "lsp" in r

    def test_kiro_code_analysis_covers_debugging(self):
        r = Path(".kiro/rules/code-analysis.md").read_text()
        assert "调试" in r or "debug" in r.lower()
        assert "get_diagnostics" in r
