# oh-my-claude-code

**Turn your AI coding agent into a self-evolving, personalized super-intelligence.**

Like oh-my-zsh for Zsh, but for AI coding agents. A framework that makes your agent learn from every interaction, persist valuable knowledge, and get stronger over time — automatically.

Works with: **Claude Code** | **Kiro CLI** | **OpenCode** | Any CLAUDE.md-compatible agent

---

## The Problem

You use AI coding agents every day. But every new session starts from zero. The agent forgets your preferences, repeats the same mistakes, loses valuable context, and never truly understands your workflow.

**What if your agent could compound its intelligence over time?**

## Inspiration

This framework is inspired by how the best AI engineers actually work:

**Boris Cherny** (creator of Claude Code) [shared his workflow](https://www.reddit.com/r/ClaudeAI/comments/1ql1ofh/claude_code_creator_boris_explains_cowork_agentic/) — the Claude Code team shares a single CLAUDE.md checked into git, and the whole team contributes to it multiple times a week. When Claude does something wrong, they add it to CLAUDE.md so it doesn't happen again. As [paddo.dev summarized](https://paddo.dev/blog/how-boris-uses-claude-code/): *"This is Compounding Engineering in practice. Every correction becomes permanent context. The cost of a mistake pays dividends forever."*

Boris's most important tip: **give Claude a way to verify its work** — if Claude has that feedback loop, it will 2-3x the quality of the final result.

The [emerging consensus among top agentic engineers](https://www.youtube.com/watch?v=ttdWPDmBN_4&t=17s) points to the same patterns: plan before you code, codify lessons into persistent files, use hooks for automated guardrails, and build feedback loops that make the agent self-correct.

**oh-my-claude-code takes these principles and turns them into a ready-to-use framework** — so you don't have to build the scaffolding yourself.

## The Philosophy

This framework is built on 4 core beliefs:

### 🔄 Compound Interest Engineering

> Every interaction should make the agent permanently smarter.

Most AI setups are disposable — chat, get answer, forget. oh-my-claude-code treats every correction, every preference, every lesson as an **investment**. The agent captures learnings in real-time and writes them to persistent files. Day 1 it's generic. Day 30 it knows your codebase, your style, your decision patterns. Day 100 it's an extension of your brain.

```
Day 1:   Generic AI assistant
Day 30:  Knows your preferences, avoids past mistakes
Day 100: Personalized super-intelligence that thinks like you
```

### 💾 Auto-Persist Valuable Intermediate Results

> If it's worth generating, it's worth saving.

Structured output vanishing in chat history is a tragedy. This framework enforces a simple rule: **every valuable intermediate result gets written to a file**. Research findings → `knowledge/`. Plans → `plans/`. Lessons → `lessons-learned.md`. Nothing valuable is lost.

### 🧠 Feedback Loop → Self-Evolution

> The agent detects your corrections and rewires itself.

When you say "no, use X not Y", the agent doesn't just comply — it **captures the pattern**, classifies it by confidence (70-90%), and writes it to the appropriate layer of its instruction set. Next time, it won't need correcting. This is a closed-loop self-evolution system:

```
You correct the agent
       ↓
Agent detects the correction pattern
       ↓
Writes to persistent instruction file (immediately, no queue)
       ↓
Next session, the agent already knows
       ↓
You correct less and less over time
       ↓
🎯 Personalized super-intelligence
```

### ⚙️ As-Code Constraints + Persistent Memory

> If it can be enforced by code, don't enforce it with words.

Natural language instructions drift. Code doesn't. This framework uses **hooks** (automated scripts that run at key moments) to enforce rules that matter. Combined with a structured **knowledge base** for persistent memory, your agent evolves within guardrails — getting smarter without going off the rails.

## Architecture: 3 Layers

```
┌─────────────────────────────────────────┐
│  Layer 1: Enforcement (Code)            │  ← Hooks, linters, tests
│  Rules enforced automatically.          │    Zero drift. Zero forgetting.
│  No reliance on the agent "remembering" │
├─────────────────────────────────────────┤
│  Layer 2: High-Frequency Recall         │  ← CLAUDE.md / AGENTS.md (≤200 lines)
│  Core rules read EVERY conversation.    │    Strict budget forces discipline.
│  The agent's "working memory."          │
├─────────────────────────────────────────┤
│  Layer 3: On-Demand Reference           │  ← Linked .md files, knowledge/
│  Deep docs, templates, SOPs.            │    Loaded only when needed.
│  The agent's "long-term memory."        │    No context window waste.
└─────────────────────────────────────────┘
```

Why 3 layers? Because a single flat file either wastes context window (too detailed) or misses important rules (too brief). This architecture gives you both precision and depth.

## Features

### 🚨 3 Iron Rules (Hook-Enforced)

Every task passes through these gates — not as suggestions, but as automated checks:

| # | Rule | Why It Matters |
|---|------|---------------|
| 1 | **Research First** | Prevents hallucination. Check before answering. |
| 2 | **Skill First** | Prevents reinventing the wheel. Reuse what exists. |
| 3 | **Toolify First** | Prevents repetition. If done 3x, make it a tool. |

### 🧠 Self-Reflect — The Agent That Rewires Itself

Most agents forget your corrections the moment the session ends. Self-Reflect changes that fundamentally.

**How it works:** The agent monitors every message for correction patterns — explicit ("no, use X not Y"), implicit ("you missed..."), and even positive reinforcement ("perfect, keep doing this"). Each detection is scored by confidence (70-90%) and automatically routed to the right file in the 3-layer architecture.

```
User: don't add comments unless I ask
Agent: 📝 Learning captured: 'don't add comments unless I ask'
       → Written to CLAUDE.md (high-frequency rule)
       
       Got it, no comments unless requested.
```

**What gets captured and where:**

| Pattern | Example | Confidence | Written To |
|---------|---------|-----------|------------|
| Explicit correction | "no, use gpt-5.1 not gpt-5" | 90% | Global config |
| Implicit negation | "you missed the error handling" | 80% | Project CLAUDE.md |
| Style preference | "remember: always use TypeScript" | 90% | Project CLAUDE.md |
| Positive reinforcement | "perfect, keep doing this" | 70% | Reference layer |

**The result:** Day 1, you correct the agent 20 times. Day 30, maybe twice. Day 100, it thinks like you.

**Commands:** `/reflect` (review & sync) · `/view-queue` (see pending) · `/skip-reflect` (clear queue)

### 🔍 Multi-Level Research — Smart, Cost-Aware Information Gathering

Most agents either never search (and hallucinate) or always search (and waste API credits). This skill implements a tiered strategy that picks the cheapest source that can answer the question:

```
Level 0: Built-in knowledge     → Free, instant
         ↓ Can't answer?
Level 1: Web search              → Free, 2-3 seconds
         ↓ Need depth?
Level 2: Tavily Deep Research    → API credits, 30-120 seconds
```

**The agent is trained to stay at the lowest level possible.** Common knowledge? Level 0. Quick fact check? Level 1. Competitive analysis or deep technical comparison? Level 2.

```bash
# Deep research with structured output
./scripts/research.sh '{"input": "React vs Vue in 2026", "model": "pro"}' report.md

# Quick lookup
./scripts/research.sh '{"input": "Next.js app router conventions", "model": "mini"}'
```

Supports structured JSON output schemas, multiple citation formats (numbered, MLA, APA, Chicago), and automatic model selection.

### 🚫 Dangerous Command Blocker — Safety Net for Destructive Operations

The `block-dangerous-commands.sh` hook runs before every bash execution. It intercepts destructive commands — `rm`, `git reset --hard`, `sudo`, piping curl to shell — and blocks them with safe alternatives. `git checkout` without `-b` is blocked too, preventing accidental loss of staged/unstaged work.

This is a hard block (exit code 2), not a suggestion. The agent must explain the risk, get explicit confirmation, and use the safest alternative.

### 🛡️ Anti-Hallucination Guard — Catch Lies Before They're Written

The `enforce-research.sh` hook runs before every file write. If the agent is about to write an unsupported negative claim — "doesn't support", "no mechanism", "not available" — the hook intercepts it and forces verification against official docs first.

This was born from a real mistake: an agent confidently wrote "this platform has no hook mechanism" into a doc — when it actually did. The hook ensures the agent proves its claims before committing them to files.

### 📚 Knowledge System — Persistent Memory That Grows

```
User question → knowledge/INDEX.md → topic indexes → source documents
```

Unlike chat history that gets truncated, the knowledge system is a **permanent, structured, indexed memory**:

- **INDEX.md** acts as a routing table — the agent knows where to look before it looks
- **Topic directories** organize knowledge by domain (you define the structure)
- **lessons-learned.md** is episodic memory — mistakes and wins, so the agent never repeats errors
- **Every piece of knowledge is citable** — the agent must reference its source, no hallucinated citations

The knowledge base grows organically as you work. Research results, extracted data, plans — all automatically persisted and indexed.

### 🔧 Self-Maintenance Commands

The framework maintains itself:

| Command | What It Does |
|---------|-------------|
| `@lint` | Audits your CLAUDE.md — checks line count against 200-line budget, finds rules that should be hooks instead of prose, suggests migrations |
| `@compact` | Compresses Layer 2 — moves low-frequency rules to Layer 3, merges duplicates, tightens wording. Keeps your agent instructions sharp. |

## 📦 23 Pre-installed Skills — Curated from the Best

The framework ships with **23 battle-tested skills** from top sources in the Claude Code ecosystem:

- 🏆 **[Superpowers](https://github.com/obra/superpowers)** by Jesse Vincent (Obra) — The most popular agentic skills framework for Claude Code. A proven software development methodology used by thousands of developers. Our dev workflow skills (brainstorming, TDD, debugging, code review, etc.) come from this collection.
- 🧠 **Framework originals** — Self-reflect (self-learning system) and multi-level research are built specifically for this framework.

Skills activate automatically based on what you're doing — no manual invocation needed.

### 🔧 Development Workflow — from Superpowers (12 skills)

The complete software development lifecycle, from idea to merge:

| Skill | When It Activates |
|-------|-------------------|
| `brainstorming` | Before any creative work — explores intent before implementation |
| `writing-plans` | When you have a spec — structured, reviewable plan |
| `executing-plans` | When you have a plan — executes with review checkpoints |
| `systematic-debugging` | When hitting a bug — root cause analysis, not random fixes |
| `test-driven-development` | When implementing features — tests first, then code |
| `requesting-code-review` | When work is done — structured self-review before merge |
| `receiving-code-review` | When getting feedback — technical rigor, not blind agreement |
| `verification-before-completion` | Before claiming "done" — evidence before assertions |
| `using-git-worktrees` | When starting feature work — isolated parallel development |
| `finishing-a-development-branch` | When implementation is complete — merge, PR, or cleanup |
| `dispatching-parallel-agents` | When facing 2+ independent tasks — parallel execution |
| `subagent-driven-development` | When executing plans — delegate to subagents |

### ✍️ Writing & Communication (3 skills)

| Skill | When It Activates |
|-------|-------------------|
| `writing-clearly-and-concisely` | When writing prose — Strunk's rules for stronger writing |
| `humanizer` | When editing text — removes AI-generated writing patterns |
| `doc-coauthoring` | When writing docs/proposals — structured co-authoring workflow |

### 🔍 Analysis & Quality (5 skills)

| Skill | When It Activates |
|-------|-------------------|
| `code-review-expert` | When reviewing git changes — SOLID, security, actionable improvements |
| `security-review` | At the end of every task — audits for vulnerabilities |
| `mermaid-diagrams` | When visualizing architecture — class, sequence, flow, ER diagrams |
| `find-skills` | When looking for capabilities — discovers installable skills |
| `java-architect` | When building Java/Spring Boot apps — enterprise patterns, WebFlux, JPA |

### 🧠 Framework Core (3 skills)

| Skill | When It Activates |
|-------|-------------------|
| `self-reflect` | When you correct the agent — captures and persists the learning |
| `research` | When information is needed — multi-level search with cost awareness |
| `skill-creator` | When creating new skills — guides skill design and structure |

## Project Structure

```
.
├── CLAUDE.md                          # Layer 2: Working memory (Claude Code)
├── AGENTS.md                          # Layer 2: Working memory (Kiro CLI)
├── .kiro/
│   ├── rules/
│   │   ├── enforcement.md             # Layer 1: Code-enforced rules
│   │   ├── reference.md               # Layer 3: Long-term memory
│   │   └── commands.md                # @lint, @compact
│   ├── hooks/
│   │   ├── three-rules-check.sh       # Iron rules enforcement
│   │   ├── enforce-skill-chain.sh     # Mandatory skill chain (Kiro)
│   │   ├── enforce-skill-chain-cc.sh  # Mandatory skill chain (Claude Code)
│   │   ├── enforce-research.sh        # Anti-hallucination
│   │   ├── block-dangerous-commands.sh    # Dangerous command blocker (Kiro)
│   │   ├── block-dangerous-commands-cc.sh # Dangerous command blocker (Claude Code)
│   │   ├── enforce-lessons.sh         # Lessons-learned check (stop)
│   │   └── check-persist.sh           # Auto-persist reminder
│   ├── skills/                        # 21 pre-installed skills
│   │   ├── self-reflect/              #   🧠 Self-learning system
│   │   ├── research/                  #   🔍 Multi-level research
│   │   ├── brainstorming/             #   💡 Creative exploration
│   │   ├── writing-plans/             #   📋 Plan before code
│   │   ├── systematic-debugging/      #   🐛 Root cause analysis
│   │   ├── security-review/           #   🔒 Vulnerability audit
│   │   └── ... (15 more)             #   See full list above
│   └── agents/
│       └── default.json               # Agent config with hooks
├── knowledge/
│   ├── INDEX.md                       # Knowledge routing table
│   └── lessons-learned.md             # Episodic memory
├── plans/                             # Persisted task plans
├── tools/                             # Reusable scripts
│   └── init-project.sh                # Bootstrap new projects
└── templates/                         # Reusable templates
```

## Quick Start

### Option 1: Clone and customize (Recommended)

```bash
git clone https://github.com/KaimingWan/oh-my-claude-code.git my-project
cd my-project
# Edit CLAUDE.md — define your agent's identity, roles, and rules
# Start chatting — the agent evolves from here
```

**Pull upstream updates anytime:**

```bash
git pull origin main
```

Your customizations live in `CLAUDE.md`, `knowledge/`, and `plans/` — upstream updates to hooks, skills, and the framework won't conflict with your project-specific content.

### Option 2: Add to existing project

```bash
git clone https://github.com/KaimingWan/oh-my-claude-code.git /tmp/omcc
/tmp/omcc/tools/init-project.sh ./my-project "My Project"
```

### Option 3: Cherry-pick

| Want | Copy |
|------|------|
| Just the 3-layer structure | `CLAUDE.md` + `.kiro/rules/` |
| Just the hooks | `.kiro/hooks/` + `.kiro/agents/` |
| Just self-learning | `.kiro/skills/self-reflect/` |
| Just knowledge system | `knowledge/` |

### Troubleshooting

**Kiro CLI: "user defined default not found"**

If you see `Error: user defined default default not found` on startup, create a global default agent:

```bash
mkdir -p ~/.kiro/agents
echo '{"name":"default","description":"Global default","tools":["*"],"allowedTools":["*"]}' > ~/.kiro/agents/default.json
```

The project-level `.kiro/agents/default.json` (with hooks) will override this automatically.

## Compatibility

| Tool | Config | Hooks | Skills | Status |
|------|--------|-------|--------|--------|
| **Claude Code** | `CLAUDE.md` | ✅ | ✅ | Full support |
| **Kiro CLI** | `AGENTS.md` | ✅ | ✅ | Full support |
| **OpenCode** | `AGENTS.md` | — | — | Instructions work |
| **Others** | `CLAUDE.md` | — | — | Instructions work |

## Design Principles

1. **Compound over time** — Every session makes the next one better
2. **Persist everything valuable** — Chat is ephemeral, files are forever
3. **Closed-loop evolution** — Corrections → persistent rules → fewer corrections
4. **Code over prose** — Hooks enforce, words suggest
5. **Budget your context** — 200-line cap keeps Layer 2 sharp
6. **Research before action** — Never guess when you can verify

## Contributing

PRs welcome! The bar for Layer 2 additions is intentionally high — if it can be a hook, make it a hook. If it's not needed every conversation, it belongs in Layer 3.

## License

MIT
