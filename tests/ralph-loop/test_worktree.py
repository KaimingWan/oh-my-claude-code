import pytest
import subprocess
from pathlib import Path
import os
import shutil
from scripts.lib.worktree import WorktreeManager


@pytest.fixture
def git_repo(tmp_path):
    original_dir = os.getcwd()
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

    wm = WorktreeManager()
    yield tmp_path
    try:
        wm.cleanup_all()
    except Exception:
        pass
    os.chdir(original_dir)


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


def test_create_duplicate_name(git_repo):
    wm = WorktreeManager()

    path = wm.create("dup")
    assert path.exists()

    # Second create with same name should not crash
    path2 = wm.create("dup")
    assert path2.exists()
    assert path2 == path

    wm.cleanup_all()


def test_cleanup_stale_with_registered_worktree(git_repo):
    wm = WorktreeManager()

    # Create a real worktree so it's registered in git
    path = wm.create("stale-test")
    assert path.exists()

    # Manually delete the directory to simulate stale state
    shutil.rmtree(path)
    assert not path.exists()

    # cleanup_stale should prune git metadata and delete leftover branches
    wm.cleanup_stale()

    # Branch should be gone
    result = subprocess.run(
        ["git", "branch", "--list", "ralph-worker-stale-test"],
        capture_output=True, text=True
    )
    assert result.stdout.strip() == ""


def test_merge_no_docs_plans(git_repo):
    wm = WorktreeManager()

    # Create worktree and add a file that does NOT touch docs/plans/
    worktree_path = wm.create("no-plans-test")
    code_file = worktree_path / "feature.py"
    code_file.write_text("x = 1")

    subprocess.run(["git", "add", "feature.py"], cwd=worktree_path, check=True)
    subprocess.run(["git", "commit", "-m", "Add feature without plans"], cwd=worktree_path, check=True)

    # Merge should succeed without error even though docs/plans/ wasn't changed
    result = wm.merge("no-plans-test")
    assert result is True

    main_feature = git_repo / "feature.py"
    assert main_feature.exists()


def test_remove_already_removed(git_repo):
    wm = WorktreeManager()

    # Create and then remove
    wm.create("remove-test")
    wm.remove("remove-test")

    # Second remove should not raise
    wm.remove("remove-test")