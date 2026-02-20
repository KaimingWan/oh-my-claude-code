"""Tests for generate_configs.py."""
import subprocess, json, sys, os
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from scripts.generate_configs import _main_agent_resources, _build_main_agent, load_overlay, default_agent, pilot_agent


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




def test_build_main_agent_exists():
    """_build_main_agent accepts include_regression flag; pilot and default share it."""
    # Direct API: include_regression controls require-regression hook
    result = _build_main_agent("test", include_regression=False)
    assert result["name"] == "test"
    assert "hooks" in result

    result_with_regression = _build_main_agent("test", include_regression=True)
    cmds = [h.get("command", "") for h in result_with_regression["hooks"]["preToolUse"]]
    assert any("require-regression" in c for c in cmds)

    result_without = _build_main_agent("test", include_regression=False)
    cmds = [h.get("command", "") for h in result_without["hooks"]["preToolUse"]]
    assert not any("require-regression" in c for c in cmds)

    # Both agents use it — verify structural equality of shared fields
    d = default_agent()
    p = pilot_agent()
    assert d['tools'] == p['tools']
    assert d['allowedTools'] == p['allowedTools']
    assert d['resources'] == p['resources']
    assert d['toolsSettings'] == p['toolsSettings']
    # Names differ
    assert d['name'] == 'default'
    assert p['name'] == 'pilot'
    # pilot has require-regression hook that default doesn't
    p_cmds = [h.get('command', '') for h in p['hooks']['preToolUse']]
    d_cmds = [h.get('command', '') for h in d['hooks']['preToolUse']]
    assert any('require-regression' in c for c in p_cmds)
    assert not any('require-regression' in c for c in d_cmds)


# ── Overlay tests ──────────────────────────────────────────────────────────

def test_no_overlay_backward_compatible():
    """Running without --overlay produces same output as before (backward compat)."""
    r = subprocess.run(
        ["python3", "scripts/generate_configs.py"],
        capture_output=True, text=True,
    )
    assert r.returncode == 0, f"stderr: {r.stderr}"
    cfg = json.loads(Path(".kiro/agents/pilot.json").read_text())
    # Original resources are present
    assert "file://AGENTS.md" in cfg["resources"]
    assert "skill://skills/planning/SKILL.md" in cfg["resources"]
    # No spurious extra resources
    extra = [r for r in cfg["resources"] if r not in (
        "file://AGENTS.md", "file://knowledge/INDEX.md",
        "skill://skills/planning/SKILL.md", "skill://skills/reviewing/SKILL.md",
    )]
    assert extra == [], f"Unexpected extra resources: {extra}"


def test_overlay_extra_skills(tmp_path):
    """extra_skills from overlay are appended to agent resources."""
    # Create a fake skill directory with SKILL.md
    skill_dir = tmp_path / "skills" / "my-skill"
    skill_dir.mkdir(parents=True)
    (skill_dir / "SKILL.md").write_text("# My Skill\n")

    overlay = tmp_path / ".omcc-overlay.json"
    overlay.write_text(json.dumps({"extra_skills": ["skills/my-skill"]}))

    extra_skills, extra_hooks = load_overlay(overlay, tmp_path)
    assert extra_skills == ["skills/my-skill"]
    assert extra_hooks == {}

    resources = _main_agent_resources(extra_skills)
    assert "skill://skills/my-skill/SKILL.md" in resources
    # Original resources still present
    assert "file://AGENTS.md" in resources
    assert "skill://skills/planning/SKILL.md" in resources


def test_overlay_extra_hooks(tmp_path):
    """extra_hooks from overlay are merged into agent hook arrays."""
    # Create a fake hook script
    hook_dir = tmp_path / "hooks" / "project"
    hook_dir.mkdir(parents=True)
    hook_script = hook_dir / "my-hook.sh"
    hook_script.write_text("#!/bin/bash\necho ok\n")
    hook_script.chmod(0o755)

    overlay = tmp_path / ".omcc-overlay.json"
    overlay.write_text(json.dumps({
        "extra_hooks": {
            "preToolUse": [{"matcher": "execute_bash", "command": "hooks/project/my-hook.sh"}]
        }
    }))

    extra_skills, extra_hooks = load_overlay(overlay, tmp_path)
    assert extra_hooks == {
        "preToolUse": [{"matcher": "execute_bash", "command": "hooks/project/my-hook.sh"}]
    }

    # Verify agent builder merges the hook
    cfg = pilot_agent(extra_skills=[], extra_hooks=extra_hooks)
    pre_tool_cmds = [h.get("command", "") for h in cfg["hooks"]["preToolUse"]]
    assert "hooks/project/my-hook.sh" in pre_tool_cmds


def test_overlay_invalid_skill_path(tmp_path):
    """Overlay with extra_skills path missing SKILL.md raises ValueError."""
    import pytest
    overlay = tmp_path / ".omcc-overlay.json"
    overlay.write_text(json.dumps({"extra_skills": ["skills/nonexistent"]}))

    with pytest.raises(ValueError, match="missing SKILL.md"):
        load_overlay(overlay, tmp_path)
