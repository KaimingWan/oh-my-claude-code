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
