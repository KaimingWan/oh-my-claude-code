# oh-my-claude-code

A battle-tested framework for building **self-improving AI coding agents**. Like oh-my-zsh for your AI coding assistant.

Works with: **Claude Code** | **Kiro CLI** | **OpenCode** | Any CLAUDE.md-compatible agent

---

## Why This Exists

Most AI coding setups are flat — a single instruction file that grows into an unmanageable mess. This framework introduces a **3-layer architecture** that keeps your agent sharp, self-correcting, and continuously improving.

```
┌─────────────────────────────────────────┐
│  Layer 1: Enforcement (Code)            │  ← Hooks, linters, tests
│  "If it can be enforced by code,        │    Auto-enforced. Zero drift.
│   don't enforce it with words."         │
├─────────────────────────────────────────┤
│  Layer 2: High-Frequency Recall         │  ← CLAUDE.md / AGENTS.md
│  Core rules the agent reads EVERY turn. │    ≤200 lines. Stays lean.
│  Strict line budget forces discipline.  │
├─────────────────────────────────────────┤
│  Layer 3: On-Demand Reference           │  ← Linked .md files
│  Deep docs, templates, SOPs.            │    Loaded only when needed.
│  No context window waste.               │
└─────────────────────────────────────────┘
```

## ✨ Features

### 🔁 3 Iron Rules (Enforced via Hooks)

Every task must pass through these gates before execution:

| # | Rule | What It Means |
|---|------|---------------|
| 1 | **Research First** | Check best practices before answering. Don't guess. |
| 2 | **Skill First** | Is there an existing skill/template that handles this? |
| 3 | **Toolify First** | If you're doing it 3+ times, make it reusable. |

These aren't suggestions — they're enforced by `hooks/three-rules-check.sh` on every user message.

### 🧠 Self-Learning (Self-Reflect Skill)

The agent learns from your corrections in real-time and never makes the same mistake twice:

```
User corrects agent → Agent detects correction → Writes to target file immediately
                                                  (No queue. No delay.)
```

**How it works:**
- Detects correction patterns with confidence scoring (70-90%)
- Captures both negative corrections ("no, use X") and positive reinforcement ("perfect!")
- Routes learnings to the right layer automatically
- Maintains an episodic memory in `knowledge/lessons-learned.md`

**Commands:**
| Command | Purpose |
|---------|---------|
| `/reflect` | Review & sync pending learnings to 3-layer architecture |
| `/view-queue` | See what the agent has learned |
| `/skip-reflect` | Clear the learning queue |

### 🔍 Multi-Level Research

Built-in research strategy that minimizes cost while maximizing quality:

| Level | Tool | Use Case | Cost |
|-------|------|----------|------|
| 0 | Built-in knowledge | Common concepts | Free |
| 1 | `web_search` | Quick verification | Free |
| 2 | Tavily Research API | Deep research, competitive analysis | API credits |

**Rule**: Always use the lowest level that answers the question. The agent is trained to not waste API credits on questions it can answer from built-in knowledge.

```bash
# Quick research
./scripts/research.sh '{"input": "quantum computing trends"}'

# Deep research with structured output
./scripts/research.sh '{"input": "AI agents comparison", "model": "pro"}' report.md
```

### 🛡️ Anti-Hallucination Guard

The `enforce-research.sh` hook intercepts file writes containing unsupported negative claims ("doesn't support", "no mechanism", "not available") and forces the agent to verify against official docs first.

### 🪝 Hook System

Automated guardrails that run at key moments:

| Hook | Trigger | Purpose |
|------|---------|---------|
| `three-rules-check.sh` | Every user message | Enforces the 3 iron rules |
| `enforce-research.sh` | Before file writes | Catches hallucinated claims |
| `check-persist.sh` | After agent responds | Reminds to persist structured output |

### 📐 Meta Rules: The Constitution

> **If it can be enforced by code, don't enforce it with words.**

This single principle keeps the system healthy. Before adding any rule:

| Ask | If yes → |
|-----|----------|
| Can this be a linter/test/hook? | Write code, not prose |
| Is this needed every conversation? | Layer 2 (≤200 lines) |
| Is this detailed but rare? | Layer 3 (reference) |

### 📚 Knowledge System

Structured knowledge with index-based retrieval:

```
User question → knowledge/INDEX.md → topic indexes → source documents
```

The agent always cites sources. No hallucinated references.

### 🔧 Custom Commands

| Command | Purpose |
|---------|---------|
| `@lint` | Health check — line count, find rules that should be code |
| `@compact` | Compress instructions, move low-freq rules to reference layer |

## Project Structure

```
.
├── CLAUDE.md                          # High-frequency recall (Claude Code)
├── AGENTS.md                          # High-frequency recall (Kiro CLI / OpenCode)
├── .claude/
│   └── settings.json                  # Claude Code permissions
├── .kiro/
│   ├── rules/
│   │   ├── enforcement.md             # Layer 1: What's enforced by code
│   │   ├── reference.md               # Layer 3: On-demand detailed docs
│   │   └── commands.md                # Custom commands (@lint, @compact)
│   ├── hooks/
│   │   ├── three-rules-check.sh       # 3 iron rules enforcement
│   │   ├── enforce-research.sh        # Anti-hallucination guard
│   │   └── check-persist.sh           # Persistence reminder
│   ├── skills/
│   │   ├── self-reflect/              # 🧠 Self-learning system
│   │   │   ├── SKILL.md
│   │   │   ├── reflect_utils.py
│   │   │   └── commands/
│   │   └── research/                  # 🔍 Multi-level research
│   │       ├── SKILL.md
│   │       └── scripts/research.sh
│   └── agents/
│       └── default.json               # Agent configuration with hooks
├── knowledge/
│   ├── INDEX.md                       # Knowledge routing table
│   └── lessons-learned.md             # Episodic memory
├── plans/                             # Task plans and specs
├── tools/
│   └── init-project.sh                # Bootstrap new projects
└── templates/                         # Reusable templates
```

## Quick Start

### Option 1: Clone and customize

```bash
git clone https://github.com/KaimingWan/oh-my-claude-code.git my-project
cd my-project
# Edit CLAUDE.md to define your agent's identity and roles
```

### Option 2: Initialize in existing project

```bash
git clone https://github.com/KaimingWan/oh-my-claude-code.git /tmp/omcc
/tmp/omcc/tools/init-project.sh ./my-existing-project "My Project"
```

### Option 3: Cherry-pick what you need

Just copy the specific pieces:
- Only want hooks? → Copy `.kiro/hooks/`
- Only want the 3-layer structure? → Copy `CLAUDE.md` + `.kiro/rules/`
- Only want self-learning? → Copy `.kiro/skills/self-reflect/`
- Only want knowledge system? → Copy `knowledge/`

## Customization

### Define Your Agent's Identity

Edit `CLAUDE.md` (or `AGENTS.md` for Kiro):

```markdown
## Identity
- **Name**: My Project Agent
- **Language**: English

## Roles
| Role | Trigger | Knowledge Source |
|------|---------|-----------------|
| 🔧 Engineer | Technical tasks | `knowledge/tech/` |
| 📣 Writer | Content creation | `knowledge/content/` |
```

### Add Knowledge

```bash
mkdir -p knowledge/my-topic
# Add your .md files
# Update knowledge/INDEX.md with routing rules
```

### Add Custom Hooks

Create a script in `.kiro/hooks/`, register in `.kiro/agents/default.json`:

```json
{
  "hooks": {
    "userPromptSubmit": [
      { "command": ".kiro/hooks/my-hook.sh" }
    ]
  }
}
```

## Compatibility

| Tool | Config File | Hooks | Skills | Status |
|------|------------|-------|--------|--------|
| **Claude Code** | `CLAUDE.md` | `.claude/settings.json` | ✅ | ✅ Full support |
| **Kiro CLI** | `AGENTS.md` | `.kiro/hooks/` + `.kiro/agents/` | ✅ | ✅ Full support |
| **OpenCode** | `AGENTS.md` | — | — | ✅ Instructions work |
| **Others** | `CLAUDE.md` | — | — | ✅ Instructions work |

## Design Principles

1. **Code over prose** — Enforce with hooks/linters, not instructions
2. **Budget your context** — 200-line cap on high-frequency layer
3. **Compound interest** — Every correction makes the agent permanently better
4. **Research before action** — Never guess when you can verify
5. **Persist everything** — Structured output goes to files, not just chat

## Contributing

PRs welcome! The bar for adding to Layer 2 (high-frequency) is intentionally high — see the meta rules. If you've discovered a pattern that makes AI coding agents better, we'd love to see it.

## License

MIT
