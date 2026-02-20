import pytest
from pathlib import Path

SKILL = Path("skills/debugging/SKILL.md").read_text()
REF = Path("skills/debugging/reference.md").read_text()

class TestDebuggingSkillContent:
    def test_has_tool_decision_matrix(self):
        assert "## Tool Decision Matrix" in SKILL

    def test_has_lsp_tools_in_phase1(self):
        p1_start = SKILL.index("### Phase 1")
        p2_start = SKILL.index("### Phase 2")
        p1 = SKILL[p1_start:p2_start]
        for tool in ["get_diagnostics", "search_symbols", "find_references"]:
            assert tool in p1, f"Phase 1 missing {tool}"

    def test_has_diagnostic_evidence_requirement(self):
        assert "Diagnostic Evidence" in SKILL

    def test_has_pre_post_diagnostics(self):
        assert SKILL.count("get_diagnostics") >= 3

    def test_has_episodes_check(self):
        p1_start = SKILL.index("### Phase 1")
        p2_start = SKILL.index("### Phase 2")
        assert "episodes" in SKILL[p1_start:p2_start].lower()

    def test_has_iron_laws(self):
        s = SKILL.lower()
        assert "goto_definition" in s
        assert "find_references" in s
        assert "get_diagnostics" in s

    def test_preserves_existing_content(self):
        for section in ["Red Flags", "Common Rationalizations", "Quick Reference"]:
            assert section in SKILL, f"Lost existing section: {section}"

    def test_preserves_four_phases(self):
        for phase in ["Phase 1", "Phase 2", "Phase 3", "Phase 4"]:
            assert phase in SKILL, f"Lost {phase}"

    def test_reference_has_tool_recipes(self):
        for t in ["search_symbols", "goto_definition", "find_references", "get_hover", "get_diagnostics"]:
            assert t in REF, f"Reference missing {t}"
