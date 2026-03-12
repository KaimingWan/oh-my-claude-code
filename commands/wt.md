Manage worktrees: list status, clean up merged branches.

## Step 1: List all worktrees with status

Run:
```bash
echo "=== Worktrees in worktrees/ ==="
for dir in worktrees/*/; do
  [ -d "$dir" ] || continue
  dir="${dir%/}"
  BRANCH=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
  echo "  $dir → branch: $BRANCH"
done
```

## Step 2: Check merge status

For each worktree, detect its submodule by reading `.git` file and check merge status:

```bash
for dir in worktrees/*/; do
  [ -d "$dir" ] || continue
  dir="${dir%/}"
  NAME=$(basename "$dir")
  BRANCH=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || continue)

  # Detect submodule from worktree's git common dir
  COMMON=$(git -C "$dir" rev-parse --git-common-dir 2>/dev/null)
  SM=$(basename "$(dirname "$COMMON")" 2>/dev/null)
  [ -d "$SM" ] || { echo "  ⚠️ $dir — cannot detect submodule, skipping"; continue; }

  # Check if branch is merged into main
  git -C "$SM" fetch origin main --quiet 2>/dev/null
  if git -C "$SM" branch --merged origin/main 2>/dev/null | grep -q "$BRANCH"; then
    echo "  ✅ $dir ($BRANCH) — MERGED into $SM/main → safe to remove"
  else
    echo "  🔄 $dir ($BRANCH) — NOT merged into $SM/main"
  fi
done
```

## Step 3: Confirm and clean up

Show the list to the user. For worktrees marked "MERGED":
- Ask user to confirm which ones to remove
- For each confirmed removal:
```bash
git -C <submodule> worktree remove ../worktrees/<name>
```
- If `.active-submodule` exists and its worktree field matches the removed path, clear it:
```bash
if [ -f .active-submodule ] && command -v jq >/dev/null 2>&1; then
  WT=$(jq -r '.worktree // ""' .active-submodule 2>/dev/null)
  [ "$WT" = "worktrees/<name>" ] && : > .active-submodule
fi
```

## Important rules
- Only manage worktrees under `worktrees/` directory (not external paths)
- Always confirm with user before removing — never auto-delete
- Use `git -C <submodule> worktree remove` (not rm -rf)

---
User's message (the text after @wt):
