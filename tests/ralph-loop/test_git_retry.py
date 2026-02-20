"""Tests for git_retry module."""
import subprocess
import pytest
from unittest.mock import patch, MagicMock
from scripts.lib.git_retry import git_run


def test_git_run_succeeds_first_try():
    """git_run returns result on first success."""
    with patch("subprocess.run") as mock_run:
        mock_run.return_value = subprocess.CompletedProcess(args=[], returncode=0, stdout="ok", stderr="")
        result = git_run(["git", "status"])
        assert result.returncode == 0
        assert mock_run.call_count == 1


def test_git_run_retries_on_lock():
    """git_run retries on index.lock error, then succeeds."""
    lock_err = subprocess.CalledProcessError(128, "git", stderr="fatal: Unable to create index.lock")
    ok_result = subprocess.CompletedProcess(args=[], returncode=0, stdout="ok", stderr="")
    with patch("subprocess.run", side_effect=[lock_err, ok_result]) as mock_run, \
         patch("time.sleep"):
        result = git_run(["git", "merge", "--squash", "branch"], base_delay=0.01)
        assert result.returncode == 0
        assert mock_run.call_count == 2


def test_git_run_gives_up_after_max_retries():
    """git_run raises after max_retries exhausted."""
    lock_err = subprocess.CalledProcessError(128, "git", stderr="fatal: Unable to create index.lock")
    with patch("subprocess.run", side_effect=[lock_err, lock_err, lock_err, lock_err]) as mock_run, \
         patch("time.sleep"), \
         pytest.raises(subprocess.CalledProcessError):
        git_run(["git", "merge"], max_retries=3, base_delay=0.01)
    assert mock_run.call_count == 4  # 1 initial + 3 retries


def test_git_run_no_retry_on_non_lock_error():
    """git_run does NOT retry on non-lock errors."""
    err = subprocess.CalledProcessError(1, "git", stderr="fatal: not a git repository")
    with patch("subprocess.run", side_effect=err) as mock_run, \
         pytest.raises(subprocess.CalledProcessError):
        git_run(["git", "status"], base_delay=0.01)
    assert mock_run.call_count == 1


def test_git_run_retries_on_lock_ref_error():
    """git_run should also retry on 'cannot lock ref' errors."""
    import subprocess
    from unittest.mock import patch, MagicMock
    from scripts.lib.git_retry import git_run

    call_count = 0
    def fake_run(*args, **kwargs):
        nonlocal call_count
        call_count += 1
        if call_count == 1:
            raise subprocess.CalledProcessError(1, args[0], stderr="cannot lock ref")
        return MagicMock(returncode=0)

    with patch("subprocess.run", side_effect=fake_run):
        git_run(["git", "merge", "branch"], base_delay=0.01)
    assert call_count == 2
