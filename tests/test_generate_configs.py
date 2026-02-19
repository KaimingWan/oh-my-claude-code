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


def test_idempotent_generation():
    """Running generate_configs.py twice produces identical output."""
    configs = [".claude/settings.json", ".kiro/agents/pilot.json",
               ".kiro/agents/reviewer.json", ".kiro/agents/researcher.json",
               ".kiro/agents/executor.json"]
    r1 = subprocess.run(["python3", "scripts/generate_configs.py"], capture_output=True, text=True)
    assert r1.returncode == 0
    first = {f: Path(f).read_text() for f in configs}
    r2 = subprocess.run(["python3", "scripts/generate_configs.py"], capture_output=True, text=True)
    assert r2.returncode == 0
    for f in configs:
        assert Path(f).read_text() == first[f], f"Non-idempotent: {f}"


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


def test_validate_hook_registry():
    """validate() returns 0 when hook registry is consistent."""
    from scripts.generate_configs import validate
    assert validate() == 0
