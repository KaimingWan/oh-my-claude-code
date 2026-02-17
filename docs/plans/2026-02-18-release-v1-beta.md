# Release v1.0.0-beta Implementation Plan

**Goal:** Create the first public release v1.0.0-beta with git tag, GitHub Release (highlights + changelog link), and a version badge in README.
**Non-Goals:** Running full test suite (recently passed). Changing any framework functionality. Writing detailed per-commit changelog.
**Architecture:** Tag current HEAD, add shield badge to README top, create GitHub Release via `gh release create` with curated highlights.
**Tech Stack:** Git, GitHub CLI (`gh`), Markdown

## Review

**Round 1 — 4 reviewers, all APPROVE:**
- Goal Alignment: ✅ APPROVE — all goal phrases covered, execution order correct
- Verify Correctness: ✅ APPROVE — 6 verify commands all sound (correct/broken distinguishable)
- Completeness: ✅ APPROVE — all modified files exercised by tasks
- Technical Feasibility: ✅ APPROVE — no blockers, gh CLI + git available on macOS

## Tasks

### Task 1: Add version badge to README

**Files:**
- Modify: `README.md`

**What to implement:**
Add a release badge after the H1 title line in README.md:
```
[![Release](https://img.shields.io/github/v/release/KaimingWan/oh-my-claude-code?include_prereleases)](https://github.com/KaimingWan/oh-my-claude-code/releases)
```

**Verify:**
```bash
grep -q 'img.shields.io/github/v/release' README.md
```

### Task 2: Write release notes and create GitHub Release

**Files:**
- Create: `docs/releases/v1.0.0-beta.md`

**What to implement:**
1. Create `docs/releases/v1.0.0-beta.md` with highlights:
   - 3-Layer Determinism Model (L1 Commands, L2 Gates, L3 Feedback)
   - Ralph Loop — Python outer loop for hard verify-completion
   - 9 Core Skills
   - Multi-perspective Plan Review
   - Self-learning Knowledge System
   - Kiro CLI full compatibility (12 hooks verified)
   - 76+ automated tests
2. Include compare link: `v3.0.0...v1.0.0-beta`
3. Tag and create GitHub Release:
   ```bash
   git tag v1.0.0-beta
   gh release create v1.0.0-beta --title "v1.0.0-beta" --notes-file docs/releases/v1.0.0-beta.md --prerelease
   ```

**Verify:**
```bash
test -f docs/releases/v1.0.0-beta.md && grep -q 'Highlights' docs/releases/v1.0.0-beta.md && grep -q 'v3.0.0...v1.0.0-beta' docs/releases/v1.0.0-beta.md && git tag -l v1.0.0-beta | grep -q v1.0.0-beta && gh release view v1.0.0-beta --json isPrerelease -q '.isPrerelease' | grep -q true
```

## Checklist

- [ ] README 包含 release badge | `grep -q 'img.shields.io/github/v/release' README.md`
- [ ] release notes 文件存在 | `test -f docs/releases/v1.0.0-beta.md`
- [ ] release notes 包含 highlights | `grep -q 'Highlights' docs/releases/v1.0.0-beta.md`
- [ ] release notes 包含 compare link | `grep -q 'v3.0.0...v1.0.0-beta' docs/releases/v1.0.0-beta.md`
- [ ] git tag 存在 | `git tag -l v1.0.0-beta | grep -q v1.0.0-beta`
- [ ] GitHub Release 是 prerelease | `gh release view v1.0.0-beta --json isPrerelease -q '.isPrerelease' | grep -q true`

## Errors

| Error | Task | Attempt | Resolution |
|-------|------|---------|------------|
