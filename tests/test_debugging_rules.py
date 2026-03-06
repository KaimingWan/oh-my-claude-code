import pytest
from pathlib import Path

class TestDebuggingRules:
    def test_kiro_code_analysis_covers_debugging(self):
        r = Path(".kiro/rules/code-analysis.md").read_text()
        assert "调试" in r or "debug" in r.lower()
        assert "get_diagnostics" in r
