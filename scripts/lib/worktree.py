import subprocess
from pathlib import Path
import shutil


class WorktreeManager:
    def __init__(self, base_dir=None):
        self.project_root = Path.cwd()
        self.base_dir = self.project_root / (base_dir or ".worktrees")

    def create(self, name):
        worktree_path = self.base_dir / f"ralph-{name}"
        branch_name = f"ralph-worker-{name}"

        self.base_dir.mkdir(exist_ok=True)

        # Idempotent: remove existing worktree before recreating
        if worktree_path.exists():
            self.remove(name)

        subprocess.run(["git", "worktree", "add", str(worktree_path), "-B", branch_name],
                       check=True, cwd=self.project_root)
        return worktree_path

    def merge(self, name):
        branch_name = f"ralph-worker-{name}"

        try:
            subprocess.run(["git", "merge", "--no-ff", branch_name],
                           check=True, cwd=self.project_root)

            # Only restore docs/plans/ if the merge actually changed it
            try:
                diff = subprocess.run(
                    ["git", "diff", "--name-only", "HEAD~1", "HEAD", "--", "docs/plans/"],
                    capture_output=True, text=True, check=True, cwd=self.project_root
                )
                if diff.stdout.strip():
                    subprocess.run(["git", "checkout", "HEAD~1", "--", "docs/plans/"],
                                   cwd=self.project_root)
                    subprocess.run(["git", "commit", "--amend", "--no-edit"],
                                   check=True, cwd=self.project_root)
            except subprocess.CalledProcessError:
                # diff check failed — skip restore, don't abort merge
                pass

            return True
        except subprocess.CalledProcessError:
            subprocess.run(["git", "merge", "--abort"], cwd=self.project_root)
            return False

    def remove(self, name):
        worktree_path = self.base_dir / f"ralph-{name}"
        branch_name = f"ralph-worker-{name}"

        try:
            subprocess.run(["git", "worktree", "remove", "--force", str(worktree_path)],
                           cwd=self.project_root)
        except subprocess.CalledProcessError:
            pass

        try:
            subprocess.run(["git", "branch", "-D", branch_name], cwd=self.project_root,
                           check=True)
        except subprocess.CalledProcessError:
            pass

    def cleanup_all(self):
        if self.base_dir.exists():
            for item in self.base_dir.iterdir():
                if item.is_dir() and item.name.startswith("ralph-"):
                    name = item.name[6:]  # Remove "ralph-" prefix
                    try:
                        self.remove(name)
                    except subprocess.CalledProcessError:
                        pass
        subprocess.run(["git", "worktree", "prune"], cwd=self.project_root)

    def cleanup_stale(self):
        # Prune git metadata for worktrees whose directories no longer exist
        subprocess.run(["git", "worktree", "prune"], cwd=self.project_root)

        if self.base_dir.exists():
            for item in self.base_dir.iterdir():
                if item.is_dir() and item.name.startswith("ralph-"):
                    # Remove from git worktree registry before deleting directory
                    subprocess.run(
                        ["git", "worktree", "remove", "--force", str(item)],
                        cwd=self.project_root
                    )
                    if item.exists():
                        shutil.rmtree(item)

        # Delete any leftover ralph-worker-* branches
        result = subprocess.run(["git", "branch", "--list", "ralph-worker-*"],
                                capture_output=True, text=True, cwd=self.project_root)
        for line in result.stdout.splitlines():
            branch = line.strip()
            if branch:
                subprocess.run(["git", "branch", "-D", branch], cwd=self.project_root)