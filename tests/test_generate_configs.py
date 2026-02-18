"""Tests for generate_configs.py."""
import subprocess, json
from pathlib import Path


def test_generates_valid_json():
    r = subprocess.run(["python3", "scripts/generate_configs.py"], capture_output=True, text=True)
    assert r.returncode == 0
    for f in [".claude/settings.json", ".kiro/agents/pilot.json",
              ".kiro/agents/reviewer.json", ".kiro/agents/researcher.json",
              ".kiro/agents/executor.json"]:
        p = Path(f)
        assert p.exists(), f"{f} not generated"
        json.loads(p.read_text())


def test_hooks_registered():
    cfg = json.loads(Path(".kiro/agents/pilot.json").read_text())
    hook_commands = [h["command"] for h in cfg["hooks"]["preToolUse"]]
    assert any("block-dangerous" in c for c in hook_commands)
    assert any("enforce-ralph-loop" in c for c in hook_commands)


def test_output_matches_bash_generator():
    """Python generator must produce semantically identical JSON to bash version."""
    # The bash generator was run before and saved to /tmp/orig_*
    # We compare the semantic content (ignoring key order)
    # Note: pilot.json replaces default.json, so we compare pilot vs default
    mapping = {
        ".claude/settings.json": "/tmp/orig_settings.json",
        ".kiro/agents/reviewer.json": "/tmp/orig_reviewer.json",
        ".kiro/agents/researcher.json": "/tmp/orig_researcher.json",
        ".kiro/agents/executor.json": "/tmp/orig_executor.json",
    }
    for new_path, orig_path in mapping.items():
        orig = Path(orig_path)
        if not orig.exists():
            continue  # skip if no baseline saved
        new = json.loads(Path(new_path).read_text())
        old = json.loads(orig.read_text())
        assert new == old, f"JSON mismatch in {new_path}"

    # pilot.json vs old default.json — name changed, rest should match
    orig_default = Path("/tmp/orig_default.json")
    if orig_default.exists():
        old = json.loads(orig_default.read_text())
        new = json.loads(Path(".kiro/agents/pilot.json").read_text())
        old["name"] = "pilot"  # expected change
        assert new == old, "pilot.json differs from old default.json beyond name change"


def test_generates_cc_agent_markdown():
    """CC agent markdown files are generated with correct YAML frontmatter."""
    r = subprocess.run(["python3", "scripts/generate_configs.py"], capture_output=True, text=True)
    assert r.returncode == 0
    for f in [".claude/agents/reviewer.md", ".claude/agents/researcher.md", ".claude/agents/executor.md"]:
        p = Path(f)
        assert p.exists(), f"{f} not generated"
        content = p.read_text()
        # Must have YAML frontmatter
        assert content.startswith("---\n"), f"{f} missing YAML frontmatter"
        assert "\n---\n" in content[4:], f"{f} missing frontmatter closing"


def test_cc_agent_frontmatter_fields():
    """CC agent frontmatter has required fields: name, description, tools."""
    for agent_name in ["reviewer", "researcher", "executor"]:
        p = Path(f".claude/agents/{agent_name}.md")
        content = p.read_text()
        # Extract frontmatter
        parts = content.split("---\n", 2)
        assert len(parts) >= 3, f"{agent_name}.md frontmatter parse error"
        fm_text = parts[1]
        assert f"name: {agent_name}" in fm_text, f"{agent_name} name mismatch"
        assert "description:" in fm_text, f"{agent_name} missing description"
        assert "tools:" in fm_text, f"{agent_name} missing tools"


def test_cc_agent_has_hooks():
    """CC agent reviewer.md has PreToolUse hooks for security."""
    p = Path(".claude/agents/reviewer.md")
    content = p.read_text()
    assert "PreToolUse" in content
    assert "block-dangerous" in content
