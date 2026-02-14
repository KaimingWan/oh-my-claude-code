Commit all changes, push to remote, and update README if needed. (CPU = Commit Push Update-readme)

## Steps
1. `git add -A && git status --short` — show what's staged
2. Ask user for commit message if not provided, or generate one from the diff
3. `git commit -m "<message>"`
4. `git push`
5. Report: commit hash + push result
