# oh-my-claude-code

A battle-tested framework for building **self-improving AI coding agents**. Born from real-world production use, not theory.

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

## Key Ideas

### 🔁 The 3 Iron Rules (Enforced via Hooks)

Every task must pass through these gates before execution:

| # | Rule | What It Means |
|---|------|---------------|
| 1 | **Research First** | Check best practices before answering. Don't guess. |
| 2 | **Skill First** | Is there an existing skill/template that handles this? |
| 3 | **Toolify First** | If you're doing it 3+ times, make it reusable. |

These aren't suggestions — they're enforced by `hooks/three-rules-check.sh` on every user message.

### 🧠 Self-Learning (Compound Interest)

The agent learns from corrections in real-time:

```
User corrects agent → Agent detects correction → Writes to target file immediately
                                                  (No queue. No delay.)
```

What gets captured:
- Mistakes → `knowledge/lessons-learned.md`
- Patterns → Rules in the appropriate layer
- Repeated operations (≥3x) → Templates or tools

### 📐 Meta Rules: The Constitution

> **If it can be enforced by code, don't enforce it with words.**

| Before adding a rule to CLAUDE.md, ask: | If yes → |
|----------------------------------------|----------|
| Can this be a linter/test/hook? | Write code, not prose |
| Is this needed every conversation? | Layer 2 (high-frequency) |
| Is this detailed but rare? | Layer 3 (reference) |
| Is this a duplicate? | Merge with existing |

This keeps your agent instructions lean and effective.

### 🪝 Hooks: Automated Guardrails

| Hook | Trigger | Purpose |
|------|---------|---------|
| `three-rules-check.sh` | Every user message | Reminds agent of the 3 iron rules |
| `enforce-research.sh` | Before file writes | Catches unsupported negative claims |
| `check-persist.sh` | After agent responds | Reminds to persist structured output |

### 📚 Knowledge System

Structured knowledge with index-based retrieval:

```
User question → knowledge/INDEX.md → topic indexes → source documents
```

The agent always cites sources. No hallucinated references.

## Project Structure

```
.
├── CLAUDE.md                    # Layer 2: High-frequency recall (Claude Code)
├── AGENTS.md                    # Layer 2: High-frequency recall (Kiro CLI)
├── .claude/
│   └── settings.json            # Claude Code permissions
├── .kiro/
│   ├── rules/
│   │   ├── enforcement.md       # Layer 1: What's enforced by code
│   │   ├── reference.md         # Layer 3: Detailed on-demand docs
│   │   └── commands.md          # Custom commands (@lint, @compact)
│   ├── hooks/
│   │   ├── three-rules-check.sh # Iron rules enforcement
│   │   ├── enforce-research.sh  # Anti-hallucination guard
│   │   └── check-persist.sh     # Persistence reminder
│   └── agents/
│       └── default.json         # Agent configuration
├── knowledge/
│   ├── INDEX.md                 # Knowledge routing table
│   └── lessons-learned.md       # Episodic memory
├── plans/                       # Task plans and specs
├── tools/                       # Reusable scripts
│   └── init-project.sh          # Initialize new projects
└── templates/                   # Reusable templates
```

## Quick Start

### Option 1: Clone and customize

```bash
git clone https://github.com/KaimingWan/oh-my-claude-code.git my-project
cd my-project
# Edit CLAUDE.md to define your agent's identity and roles
# Add knowledge to knowledge/
```

### Option 2: Initialize in existing project

```bash
git clone https://github.com/KaimingWan/oh-my-claude-code.git /tmp/omcc
/tmp/omcc/tools/init-project.sh ./my-existing-project "My Project"
```

### Option 3: Cherry-pick what you need

Just copy the specific files you want:
- Only want hooks? Copy `.kiro/hooks/`
- Only want the 3-layer structure? Copy `CLAUDE.md` + `.kiro/rules/`
- Only want knowledge system? Copy `knowledge/`

## Customization Guide

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

Create a script in `.kiro/hooks/`, then register it in `.kiro/agents/default.json`:

```json
{
  "hooks": {
    "userPromptSubmit": [
      { "command": ".kiro/hooks/my-hook.sh" }
    ]
  }
}
```

### Custom Commands

Built-in commands you can use in chat:

| Command | Purpose |
|---------|---------|
| `@lint` | Health check — line count, rules that should be code |
| `@compact` | Compress agent instructions, move low-freq rules to reference |

## Compatibility

| Tool | Config File | Hooks | Status |
|------|------------|-------|--------|
| **Claude Code** | `CLAUDE.md` | `.claude/settings.json` | ✅ Full support |
| **Kiro CLI** | `AGENTS.md` | `.kiro/hooks/` + `.kiro/agents/` | ✅ Full support |
| **OpenCode** | `AGENTS.md` | — | ✅ Instructions work, no hooks |
| **Others** | `CLAUDE.md` | — | ✅ Instructions work, no hooks |

## Design Principles

1. **Code over prose** — Enforce with hooks/linters, not instructions
2. **Budget your context** — 200-line cap on high-frequency layer
3. **Compound interest** — Every correction makes the agent permanently better
4. **Research before action** — Never guess when you can verify
5. **Structured output to files** — Don't let valuable output vanish in chat history

## Real-World Origin

This framework was built and refined through daily production use managing:
- Sales & GTM operations
- Technical content creation
- Customer communications
- Marketing automation
- Competitive analysis

Every rule exists because something went wrong without it.

## Contributing

PRs welcome! If you've discovered a pattern that makes AI coding agents better, open a PR. The bar for adding to Layer 2 (high-frequency) is high — see the meta rules above.

## License

MIT
