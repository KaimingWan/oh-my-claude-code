# oh-my-claude-code

**Turn your AI coding agent into a self-evolving, personalized super-intelligence.**

Like oh-my-zsh for Zsh, but for AI coding agents. A framework that makes your agent learn from every interaction, persist valuable knowledge, and get stronger over time — automatically.

Works with: **Claude Code** | **Kiro CLI**

---

## The Problem

You use AI coding agents every day. But every new session starts from zero. The agent forgets your preferences, repeats the same mistakes, loses valuable context, and never truly understands your workflow.

**What if your agent could compound its intelligence over time?**

## The Philosophy

### 🔒 Deterministic Over Hopeful

> If it can be enforced by code, don't enforce it with words.

Natural language instructions drift. Hooks don't. This framework uses a **3-layer determinism model**:

| Layer | Mechanism | Certainty |
|-------|-----------|-----------|
| L1 Commands | `@plan` `@execute` `@research` `@review` `@reflect` `@cpu` `@skill` | 100% — user triggers full workflow |
| L2 Gates | `hooks/gate/` + `hooks/security/` (PreToolUse exit 2) | 100% — hard block, agent cannot bypass |
| L3 Feedback | `hooks/feedback/` (PostToolUse/Stop) | ~50% — advisory, agent may ignore |

Lesson learned from v2: soft prompts injected via `UserPromptSubmit` were ignored repeatedly. v3 moves all critical enforcement to L1 commands and L2 hard blocks.

### 🔄 Compound Interest Engineering

> Every interaction should make the agent permanently smarter.

The agent captures corrections in real-time and writes them to persistent files. Day 1 it's generic. Day 30 it knows your codebase, your style, your decision patterns.

### 💾 Auto-Persist Valuable Results

> If it's worth generating, it's worth saving.

Research findings → `knowledge/`. Plans → `docs/plans/`. Lessons → `knowledge/rules.md` + `knowledge/episodes.md`. Nothing valuable is lost in chat.

### 🧠 Feedback Loop → Self-Evolution

> The agent detects your corrections and rewires itself.

When you say "no, use X not Y", the agent captures the pattern and writes it to the appropriate file. Next session, it won't need correcting.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  L1: Commands (User-Triggered, 100% Deterministic)       │
│  @plan · @execute · @research · @review · @reflect · @cpu · @skill  │
│  Each hardcodes the full workflow — no steps skipped.    │
├─────────────────────────────────────────────────────────┤
│  L2: Gates & Security (PreToolUse, 100% Hard Block)      │
│  require-workflow · block-dangerous · block-secrets       │
│  block-sed-json · scan-skill-injection                   │
├─────────────────────────────────────────────────────────┤
│  L3: Feedback (PostToolUse/Stop, Advisory)               │
│  auto-test · auto-lint · verify-completion               │
│  correction-detect · session-init · context-enrichment   │
├─────────────────────────────────────────────────────────┤
│  Skills (On-Demand, 9 core)                              │
│  brainstorming · planning · reviewing · debugging        │
│  verification · finishing · self-reflect · research      │
│  find-skills                                             │
├─────────────────────────────────────────────────────────┤
│  Subagents (Task Isolation, 2 specialists + MCP)         │
│  reviewer · researcher (+ ripgrep MCP · fetch MCP)       │
├─────────────────────────────────────────────────────────┤
│  Knowledge (Persistent Memory)                           │
│  rules.md · episodes.md · INDEX.md routing                 │
└─────────────────────────────────────────────────────────┘
```

## Custom Commands

The primary way to trigger workflows deterministically. Each command hardcodes the full step chain — the agent cannot skip steps.

| Command | Workflow |
|---------|----------|
| `@plan` | brainstorming → write plan (with checklist) → reviewer challenge → fix until APPROVE → user confirm |
| `@execute` | load approved plan → Ralph Loop: bash outer loop checks checklist → fresh Kiro instance per iteration → no stops until all items checked off |
| `@research` | L0 built-in knowledge → L1 web search → L2 deep research → write findings to file |
| `@review` | dispatch reviewer subagent → categorize P0-P3 → cite file:line |
| `@reflect` | manual knowledge capture → extract insight → dedup check → append to episodes.md |
| `@cpu` | commit all changes → push to remote → update README if needed |
| `@lint` | health check: CLAUDE.md line count, rules file sizes, duplication detection, sync verification |
| `@skill` | list all skills with descriptions, match user need to closest skill |

## Hook System

### L2: Hard Gates (PreToolUse — exit 2 = blocked)

| Hook | What It Does |
|------|-------------|
| `gate/require-workflow.sh` | Blocks new source files without a reviewed plan (4h window, configurable) |
| `gate/plan-structure.sh` | Validates plan has Tasks, Verify commands, and Checklist with executable verify |
| `gate/checklist-gate.sh` | Blocks checklist check-off without recent successful verify command execution |
| `gate/pre-write.sh` | Instruction file write protection + brainstorming gate for plan creation |
| `security/block-dangerous.sh` | Blocks `rm -rf`, `sudo`, `curl\|bash`, force push, etc. |
| `security/block-secrets.sh` | Scans for API keys, private keys before git commit/push |
| `security/block-sed-json.sh` | Blocks sed/awk on JSON files — use jq instead |
| `security/scan-skill-injection.sh` | Detects prompt injection in skill files |

### L3: Feedback (PostToolUse/Stop — advisory)

| Hook | What It Does |
|------|-------------|
| `feedback/auto-test.sh` | Runs tests after source file changes (30s debounce) |
| `feedback/auto-lint.sh` | Runs linter after file writes |
| `feedback/inject-plan-context.sh` | PreToolUse[write]: injects plan checklist into context (Read Before Decide) |
| `feedback/remind-update-progress.sh` | PostToolUse[write]: reminds to update progress.md after file changes |
| `feedback/verify-completion.sh` | Stop hook: checks plan checklist + re-runs all verify commands |
| `feedback/post-bash.sh` | PostToolUse[bash]: logs command execution for verify evidence |
| `feedback/context-enrichment.sh` | Research reminder + unfinished task resume |
| `feedback/correction-detect.sh` | Correction detection + auto-capture trigger |
| `feedback/session-init.sh` | Rules injection + episode cleanup + promotion reminder (once per session) |

## Skills (9 Core)

| Skill | Purpose |
|-------|---------|
| `brainstorming` | Explore requirements before implementation — one question at a time |
| `planning` | Write + execute plans with TDD structure, parallel/subagent execution strategies |
| `reviewing` | Code and plan review — request, execute, and receive reviews |
| `debugging` | Systematic: reproduce → hypothesize → verify → fix |
| `verification` | Evidence before completion claims — no shortcuts |
| `finishing` | Branch completion: merge / PR / keep / discard |
| `self-reflect` | Capture corrections → write to target file immediately |
| `research` | Multi-level: built-in → web search → deep research |
| `find-skills` | Discover available skills and match to user needs |

## Subagents (2 Specialists + MCP)

| Agent | Role | Tools | MCP | Constraint |
|-------|------|-------|-----|-----------|
| `reviewer` | Plan & code review | read, write, shell | — | Must cite file:line, never rubber-stamp |
| `researcher` | Web research + code search | read, shell | ripgrep, fetch | Cite sources, cross-verify |

Implementation/debugging tasks use ralph-loop (independent kiro-cli process with full tools including LSP) or main agent. Verification tasks use default subagent (read + shell). See AGENTS.md for delegation rules.

## Project Structure

```
.
├── AGENTS.md / CLAUDE.md          # Agent working memory (<50 lines)
├── hooks/                         # Unified hook source (single truth)
│   ├── _lib/                      # common.sh, patterns.sh, llm-eval.sh
│   ├── security/                  # block-dangerous, block-secrets, block-sed-json, scan-skill-injection
│   ├── gate/                      # require-workflow (hard block)
│   └── feedback/                  # auto-test, auto-lint, verify-completion, correction-detect, session-init, context-enrichment
├── skills/                        # 9 core skills
├── agents/                        # Subagent prompt files
├── commands/                      # Custom commands (plan, execute, debug, research, review, skill)
├── scripts/
│   ├── ralph-loop.sh                 # Ralph Loop: bash outer loop for hard verify-completion
│   └── generate-platform-configs.sh  # Single source → CC + Kiro configs
├── .claude/                       # Generated CC config
│   ├── settings.json              # Generated by scripts/
│   ├── hooks -> ../hooks          # Symlink
│   ├── skills -> ../skills        # Symlink
│   └── rules/                     # security.md, shell.md, workflow.md, subagent.md, debugging.md, git-workflow.md
├── .kiro/                         # Generated Kiro config
│   ├── agents/*.json              # Generated by scripts/
│   ├── hooks -> ../hooks          # Symlink
│   ├── skills -> ../skills        # Symlink
│   ├── prompts -> ../commands     # Symlink
│   └── rules/                     # enforcement.md, commands.md, reference.md
├── knowledge/                     # Persistent memory
│   ├── INDEX.md                   # Knowledge routing table
│   ├── rules.md                   # Keyword-section rules (smart injection by topic match)
│   ├── episodes.md                # Mistakes and wins (auto-cleanup on promotion)
│   └── reference/                 # Archived skill content
└── docs/
    ├── designs/                   # Design documents
    └── plans/                     # Active implementation plans
```

Key design: `hooks/`, `skills/`, `agents/`, `commands/` are the single source of truth. Platform configs (`.claude/`, `.kiro/`) are generated by `scripts/generate-platform-configs.sh`.

## Compatibility

| Platform | Hooks | Commands | Skills | Subagents |
|----------|-------|----------|--------|-----------|
| **Claude Code** | ✅ Full (14 events) | Via slash commands | ✅ | ✅ Full |
| **Kiro CLI** | ✅ 5 events, command type | ✅ `.kiro/prompts/` | ✅ | ✅ With constraints |

## Quick Start

### Clone and customize

```bash
git clone https://github.com/KaimingWan/oh-my-claude-code.git my-project
cd my-project
bash scripts/generate-platform-configs.sh  # Generate platform configs
# Edit AGENTS.md — define your agent's identity
# Start chatting — the agent evolves from here
```

### Add to existing project

```bash
git clone https://github.com/KaimingWan/oh-my-claude-code.git /tmp/omcc
/tmp/omcc/tools/init-project.sh ./my-project "My Project"
```

### Cherry-pick

| Want | Copy |
|------|------|
| Just hooks | `hooks/` + run `scripts/generate-platform-configs.sh` |
| Just self-learning | `skills/self-reflect/` + `knowledge/rules.md` + `knowledge/episodes.md` |
| Just knowledge system | `knowledge/` |
| Just subagents | `agents/` + `.kiro/agents/` |

## Design Principles

1. **Deterministic over hopeful** — Commands and hard blocks, not soft prompts
2. **Compound over time** — Every session makes the next one better
3. **Single source of truth** — `hooks/`, `skills/`, `commands/` → generate platform configs
4. **Code over prose** — Hooks enforce, words suggest
5. **Verification first** — Evidence before claims, always
6. **YAGNI** — 9 skills, not 22. Add when needed.

## License

MIT
