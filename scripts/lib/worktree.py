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
            subprocess.run(["git", "merge", "--squash", branch_name],
                           check=True, cwd=self.project_root)

            # Restore docs/plans/ to HEAD state (exclude plan changes from squash commit)
            subprocess.run(["git", "restore", "--staged", "docs/plans/"],
                           cwd=self.project_root, capture_output=True)
            subprocess.run(["git", "restore", "docs/plans/"],
                           cwd=self.project_root, capture_output=True)

            subprocess.run(["git", "commit", "-m", f"squash: merge {branch_name}"],
                           check=True, cwd=self.project_root)

            return True
        except subprocess.CalledProcessError:
            subprocess.run(["git", "merge", "--abort"], cwd=self.project_root,
                           capture_output=True)
            subprocess.run(["git", "reset", "--hard", "HEAD"], cwd=self.project_root,
                           capture_output=True)
            return False

    def remove(self, name):
        worktree_path = self.base_dir / f"ralph-{name}"
        branch_name = f"ralph-worker-{name}"

        try:
            subprocess.run(["git", "worktree", "remove", "--force", str(worktree_path)],
                           cwd=self.project_root, capture_output=True)
        except Exception:
            pass
        try:
            subprocess.run(["git", "branch", "-D", branch_name], cwd=self.project_root,
                           capture_output=True)
        except Exception:
            pass

    def cleanup_all(self):
        if self.base_dir.exists():
            for item in self.base_dir.iterdir():
                if item.is_dir() and item.name.startswith("ralph-"):
                    name = item.name[6:]  # Remove "ralph-" prefix
                    self.remove(name)
        subprocess.run(["git", "worktree", "prune"], cwd=self.project_root)

    def _registered_worktree_paths(self):
        """Return set of absolute paths registered as git worktrees."""
        result = subprocess.run(
            ["git", "worktree", "list", "--porcelain"],
            capture_output=True, text=True, cwd=self.project_root
        )
        paths = set()
        for line in result.stdout.splitlines():
            if line.startswith("worktree "):
                paths.add(Path(line[len("worktree "):]))
        return paths

    def cleanup_stale(self):
        # Prune git metadata for worktrees whose directories no longer exist
        subprocess.run(["git", "worktree", "prune"], cwd=self.project_root)

        # Get currently registered worktree paths (after prune)
        registered = self._registered_worktree_paths()

        if self.base_dir.exists():
            for item in self.base_dir.iterdir():
                if item.is_dir() and item.name.startswith("ralph-"):
                    # Only remove directories that are NOT active registered worktrees
                    if item.resolve() not in {p.resolve() for p in registered}:
                        subprocess.run(
                            ["git", "worktree", "remove", "--force", str(item)],
                            cwd=self.project_root, capture_output=True
                        )
                        if item.exists():
                            shutil.rmtree(item)

        # Delete ralph-worker-* branches whose worktree directories no longer exist
        try:
            result = subprocess.run(["git", "branch", "--list", "ralph-worker-*"],
                                    capture_output=True, text=True, cwd=self.project_root)
            registered_resolved = {p.resolve() for p in registered}
            for line in result.stdout.splitlines():
                branch = line.strip().lstrip("* ")
                if not branch:
                    continue
                # Derive the expected worktree path from the branch name
                # branch: ralph-worker-<name> → path: .worktrees/ralph-<name>
                suffix = branch[len("ralph-worker-"):]
                expected_path = (self.base_dir / f"ralph-{suffix}").resolve()
                if expected_path not in registered_resolved:
                    subprocess.run(["git", "branch", "-D", branch],
                                   cwd=self.project_root, capture_output=True)
        except Exception:
            pass