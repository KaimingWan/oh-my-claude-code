import pytest
import subprocess
from pathlib import Path
import os
import shutil
from scripts.lib.worktree import WorktreeManager


@pytest.fixture
def git_repo(tmp_path):
    os.chdir(tmp_path)
    subprocess.run(["git", "init"], check=True)
    subprocess.run(["git", "config", "user.name", "Test"], check=True)
    subprocess.run(["git", "config", "user.email", "test@test.com"], check=True)
    
    # Create initial commit
    (tmp_path / "README.md").write_text("# Test")
    subprocess.run(["git", "add", "README.md"], check=True)
    subprocess.run(["git", "commit", "-m", "Initial commit"], check=True)
    
    # Create docs/plans directory
    plans_dir = tmp_path / "docs" / "plans"
    plans_dir.mkdir(parents=True)
    (plans_dir / "plan.md").write_text("# Plan")
    subprocess.run(["git", "add", "docs/"], check=True)
    subprocess.run(["git", "commit", "-m", "Add plans"], check=True)
    
    return tmp_path


def test_create_and_cleanup(git_repo):
    wm = WorktreeManager()
    
    # Test create
    path = wm.create("test1")
    assert path.exists()
    assert path.name == "ralph-test1"
    
    # Test cleanup_all
    wm.cleanup_all()
    assert not path.exists()


def test_create_multiple(git_repo):
    wm = WorktreeManager()
    
    paths = []
    for i in range(4):
        path = wm.create(f"test{i}")
        paths.append(path)
        assert path.exists()
    
    wm.cleanup_all()
    for path in paths:
        assert not path.exists()


def test_stale_cleanup(git_repo):
    wm = WorktreeManager()
    
    # Create a stale directory
    stale_dir = wm.base_dir / "ralph-stale"
    stale_dir.mkdir(parents=True)
    
    wm.cleanup_stale()
    assert not stale_dir.exists()


def test_merge_success(git_repo):
    wm = WorktreeManager()
    
    # Create worktree and add file
    worktree_path = wm.create("merge-test")
    test_file = worktree_path / "new_file.txt"
    test_file.write_text("New content")
    
    subprocess.run(["git", "add", "new_file.txt"], cwd=worktree_path, check=True)
    subprocess.run(["git", "commit", "-m", "Add new file"], cwd=worktree_path, check=True)
    
    # Test merge
    result = wm.merge("merge-test")
    assert result is True
    
    # Check file appears in main
    main_file = git_repo / "new_file.txt"
    assert main_file.exists()
    assert main_file.read_text() == "New content"


def test_merge_conflict(git_repo):
    wm = WorktreeManager()
    
    # Create worktree and modify file
    worktree_path = wm.create("conflict-test")
    worktree_readme = worktree_path / "README.md"
    worktree_readme.write_text("# Modified in worktree")
    
    subprocess.run(["git", "add", "README.md"], cwd=worktree_path, check=True)
    subprocess.run(["git", "commit", "-m", "Modify in worktree"], cwd=worktree_path, check=True)
    
    # Modify same file in main (after worktree creation)
    readme = git_repo / "README.md"
    readme.write_text("# Modified in main")
    subprocess.run(["git", "add", "README.md"], check=True)
    subprocess.run(["git", "commit", "-m", "Modify in main"], check=True)
    
    # Test merge conflict
    result = wm.merge("conflict-test")
    assert result is False


def test_plan_restoration_after_merge(git_repo):
    wm = WorktreeManager()
    
    # Create worktree and modify both plan and code
    worktree_path = wm.create("plan-test")
    
    # Modify plan file in worktree
    plan_file = worktree_path / "docs" / "plans" / "plan.md"
    original_plan = plan_file.read_text()
    plan_file.write_text("# Modified Plan")
    
    # Add new code file
    code_file = worktree_path / "code.py"
    code_file.write_text("print('hello')")
    
    subprocess.run(["git", "add", "."], cwd=worktree_path, check=True)
    subprocess.run(["git", "commit", "-m", "Modify plan and add code"], cwd=worktree_path, check=True)
    
    # Test merge
    result = wm.merge("plan-test")
    assert result is True
    
    # Check plan unchanged, code merged
    main_plan = git_repo / "docs" / "plans" / "plan.md"
    main_code = git_repo / "code.py"
    
    assert main_plan.read_text() == original_plan
    assert main_code.exists()
    assert main_code.read_text() == "print('hello')"