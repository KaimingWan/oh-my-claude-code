from scripts.lib.precheck import detect_test_command, run_precheck
from pathlib import Path


def test_detect_pytest(tmp_path):
    (tmp_path / "pyproject.toml").write_text("[tool.pytest]\n")
    assert "pytest" in detect_test_command(tmp_path)


def test_detect_npm(tmp_path):
    (tmp_path / "package.json").write_text("{}\n")
    assert "npm test" in detect_test_command(tmp_path)


def test_detect_none(tmp_path):
    assert detect_test_command(tmp_path) == ""


def test_run_precheck_pass(tmp_path):
    (tmp_path / "pyproject.toml").write_text("")
    (tmp_path / "test_ok.py").write_text("def test_ok(): pass\n")
    ok, out = run_precheck(tmp_path)
    assert ok is True


def test_run_precheck_no_tests(tmp_path):
    ok, out = run_precheck(tmp_path)
    assert ok is True
    assert "No test command" in out
