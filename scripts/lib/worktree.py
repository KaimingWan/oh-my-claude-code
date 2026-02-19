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
        
        subprocess.run(["git", "worktree", "add", str(worktree_path), "-B", branch_name], 
                      check=True, cwd=self.project_root)
        return worktree_path
    
    def merge(self, name):
        branch_name = f"ralph-worker-{name}"
        
        try:
            subprocess.run(["git", "merge", "--no-ff", branch_name], 
                          check=True, cwd=self.project_root)
            
            # Restore docs/plans/ from pre-merge state
            subprocess.run(["git", "checkout", "HEAD~1", "--", "docs/plans/"], 
                          cwd=self.project_root)
            subprocess.run(["git", "commit", "--amend", "--no-edit"], 
                          check=True, cwd=self.project_root)
            return True
        except subprocess.CalledProcessError:
            subprocess.run(["git", "merge", "--abort"], cwd=self.project_root)
            return False
    
    def remove(self, name):
        worktree_path = self.base_dir / f"ralph-{name}"
        branch_name = f"ralph-worker-{name}"
        
        subprocess.run(["git", "worktree", "remove", "--force", str(worktree_path)], 
                      cwd=self.project_root)
        subprocess.run(["git", "branch", "-D", branch_name], cwd=self.project_root)
    
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
        subprocess.run(["git", "worktree", "prune"], cwd=self.project_root)
        
        if self.base_dir.exists():
            for item in self.base_dir.iterdir():
                if item.is_dir() and item.name.startswith("ralph-"):
                    shutil.rmtree(item)