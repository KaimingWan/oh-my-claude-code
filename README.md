# oh-my-claude-code

**Turn your AI coding agent into a self-evolving, personalized super-intelligence.**

Like oh-my-zsh for Zsh, but for AI coding agents. A framework that makes your agent learn from every interaction, persist valuable knowledge, and get stronger over time — automatically.

Works with: **Claude Code** | **Kiro CLI** | **OpenCode** | Any CLAUDE.md-compatible agent

---

## The Problem

You use AI coding agents every day. But every new session starts from zero. The agent forgets your preferences, repeats the same mistakes, loses valuable context, and never truly understands your workflow.

**What if your agent could compound its intelligence over time?**

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

### 🧠 Self-Reflect (Built-in Skill)

Real-time correction detection with confidence scoring:

```
User: no, use gpt-5.1 not gpt-5
Agent: 📝 Learning captured: 'use gpt-5.1 not gpt-5'
       → Written to ~/.kiro/AGENTS.md (global preference)
```

Detects: explicit corrections, implicit negation ("you missed..."), and positive reinforcement ("perfect, keep doing this").

Commands: `/reflect` · `/view-queue` · `/skip-reflect`

### 🔍 Multi-Level Research (Built-in Skill)

Cost-aware research strategy with automatic fallback:

| Level | Tool | Cost |
|-------|------|------|
| 0 | Built-in knowledge | Free |
| 1 | Web search | Free |
| 2 | Tavily Deep Research API | API credits |

Rule: never use Level 2 when Level 0 can answer it.

### 🛡️ Anti-Hallucination Guard

Hook that intercepts file writes containing unsupported negative claims ("doesn't support", "no mechanism") and forces verification against official docs.

### 📚 Knowledge System (Persistent Memory)

```
User question → knowledge/INDEX.md → topic indexes → source documents
```

Every piece of knowledge is indexed, citable, and persistent across sessions. The agent builds a growing knowledge base that compounds over time.

### 🔧 Self-Maintenance Commands

| Command | Purpose |
|---------|---------|
| `@lint` | Health check — find rules that should be code, check line budget |
| `@compact` | Compress Layer 2, move low-freq rules to Layer 3 |

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
│   │   ├── enforce-research.sh        # Anti-hallucination
│   │   └── check-persist.sh           # Auto-persist reminder
│   ├── skills/
│   │   ├── self-reflect/              # 🧠 Self-learning system
│   │   └── research/                  # 🔍 Multi-level research
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

### Option 1: Clone and customize

```bash
git clone https://github.com/KaimingWan/oh-my-claude-code.git my-project
cd my-project
# Edit CLAUDE.md — define your agent's identity, roles, and rules
# Start chatting — the agent evolves from here
```

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
