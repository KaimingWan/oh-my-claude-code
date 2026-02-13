# oh-my-claude-code

**Turn your AI coding agent into a self-evolving, personalized super-intelligence.**

Like oh-my-zsh for Zsh, but for AI coding agents. A framework that makes your agent learn from every interaction, persist valuable knowledge, and get stronger over time — automatically.

Works with: **Claude Code** | **Kiro CLI**

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

## Architecture: 6-Layer Progressive Disclosure

The framework follows one core principle: *what can be enforced by hooks, don't say in CLAUDE.md; what can be said in CLAUDE.md, don't repeat in skills; what can be loaded on-demand by skills, don't put in CLAUDE.md.*

```
┌─────────────────────────────────────────────────────────┐
│              Layer 0: Hooks (As Code)                    │
│  Security (PreToolUse) · Quality Gate (Stop/Task)        │
│  Autonomy Control (PermissionRequest)                    │
│  Rules enforced automatically. Zero drift.               │
├─────────────────────────────────────────────────────────┤
│          Layer 1: CLAUDE.md / AGENTS.md (≤80 lines)      │
│  Identity · Workflow · Verification · Skill Routing      │
│  The agent's "working memory" — read every turn.         │
├─────────────────────────────────────────────────────────┤
│          Layer 2: .claude/rules/*.md (Conditional)       │
│  security.md · code-quality.md · git-workflow.md         │
│  Loaded by path glob or always-on.                       │
├─────────────────────────────────────────────────────────┤
│          Layer 3: Skills (On-Demand)                     │
│  Core (6) · Domain (N) · Utility · Deprecated            │
│  Loaded only when the task matches.                      │
├─────────────────────────────────────────────────────────┤
│          Layer 4: Subagents (Task Isolation)              │
│  researcher · implementer · reviewer · debugger          │
│  Each with own hooks, tools, and constraints.            │
├─────────────────────────────────────────────────────────┤
│          Layer 5: Knowledge (Persistent)                  │
│  lessons-learned.md · INDEX.md routing                    │
│  5-layer knowledge stack with semantic search.           │
└─────────────────────────────────────────────────────────┘
```

## Key Features

### Hook-Enforced Constraints (Layer 0)

Critical constraints are enforced by **hooks** (automated scripts), not prompt text — the agent can't ignore them:

| Hook | Event | What It Does |
|------|-------|-------------|
| `block-dangerous-commands` | PreToolUse[Bash] | Blocks `rm -rf`, `sudo`, `curl\|bash`, force push, etc. |
| `block-secrets` | PreToolUse[Bash] | Scans for API keys, private keys before git commit/push |
| `enforce-skill-chain` | PreToolUse[Write] | Blocks new source files without a reviewed plan |
| `scan-skill-injection` | PreToolUse[Write] | Detects prompt injection in skill files |
| `context-enrichment` | UserPromptSubmit | Injects correction detection, complexity assessment, debug hints |
| `verify-completion` | Stop | 3-phase check: deterministic (B) → LLM 6-dimension gate (A) → feedback loop (C) |
| `auto-test` | PostToolUse[Write] | Runs tests after source file changes (with 30s debounce) |
| `auto-lint` | PostToolUse[Write] | Async linting after file writes |
| `auto-approve-safe` | PermissionRequest | Auto-approves non-dangerous commands (CC only) |
| `inject-subagent-rules` | SubagentStart | Injects safety rules into subagents (CC only) |

### Built-in Subagent System (Layer 4)

4 specialized subagents ship with the framework, each with their own hooks and tool constraints:

| Agent | Role | Tools | Key Constraint |
|-------|------|-------|---------------|
| `researcher` | Codebase exploration & investigation | read, shell | Cannot modify files; web search delegated to main agent |
| `implementer` | TDD coding & feature implementation | read, write, shell | Auto-test on every write; must verify before stopping |
| `reviewer` | Plan review & code review (dual mode) | read, shell | Read-only; cannot rubber-stamp; must cite file:line |
| `debugger` | Systematic root cause analysis | read, write, shell | Must reproduce first; checks lessons-learned for known issues |

### Stop Hook — Verification Before Completion

The most impactful addition. Before the agent can claim work is done, the Stop hook runs a 3-phase check:

- **Phase B (Deterministic):** Checks `.completion-criteria.md` for unchecked items, runs tests, verifies git state
- **Phase A (LLM 6-Dimension Gate):** Evaluates COMPLETE / REVIEWED / TESTED / RESEARCHED / QUALITY / GROUNDED — with evidence required
- **Phase C (Feedback Loop):** Reminds to update lessons-learned, check indexes, persist structured output

On Claude Code, this can **block** the agent from stopping. On Kiro CLI, it injects results into context for the next turn.

### Skill Chain Enforcement

Creating a new source file without a plan in `docs/plans/` → **blocked** (exit 2). Plan without a substantive `## Review` section (≥3 lines) → **blocked**. Editing existing files (str_replace/Edit) → allowed (hotfix-friendly). Emergency bypass: create `.skip-plan` file.

### Self-Learning with Hook Enforcement

The self-reflect skill now has hook backing:

1. `UserPromptSubmit` hook detects correction patterns → injects "MUST write to lessons-learned.md"
2. Agent executes task + writes learning
3. `Stop` hook Phase C checks git diff → warns if lessons-learned wasn't updated after a correction

### Long-Running Task Support

5-layer strategy for tasks that outlast a single context window:

| Layer | Strategy | Reliability |
|-------|----------|------------|
| L1 | Task decomposition → short subagent runs | ✅ High |
| L2 | PostToolUse auto-test (in-flight verification) | ✅ High |
| L3 | `.completion-criteria.md` as persistent state anchor | ✅ High |
| L4 | Stop hook B+A+C (completion check + LLM eval + feedback) | ⚠️ Medium |
| L5 | `delegate` background agent | ⚠️ Low (opaque mechanism) |

### LLM-Powered Hook Evaluation

Kiro CLI hooks only support shell scripts, not native LLM evaluation. The framework bridges this gap with `_lib/llm-eval.sh` — a unified library that calls external LLMs from shell hooks:

- Auto-detects: Gemini → Anthropic → OpenAI → Ollama (local) → graceful degradation
- Used by Stop hook Phase A for semantic quality judgment
- Used by UserPromptSubmit for task complexity assessment
- Zero-config: works without any API key (falls back to deterministic checks only)

## Features

### 🧠 Self-Reflect — The Agent That Rewires Itself

The agent monitors every message for correction patterns — explicit ("no, use X not Y"), implicit ("you missed..."), and positive reinforcement ("perfect, keep doing this"). Each detection is scored by confidence and automatically routed to the right file.

```
User: don't add comments unless I ask
Agent: 📝 Learning captured: 'don't add comments unless I ask'
       → Written to CLAUDE.md (high-frequency rule)
```

**The result:** Day 1, you correct the agent 20 times. Day 30, maybe twice. Day 100, it thinks like you.

### 🔍 Multi-Level Research — Smart, Cost-Aware Information Gathering

A tiered strategy that picks the cheapest source that can answer the question:

```
Level 0: Built-in knowledge     → Free, instant
         ↓ Can't answer?
Level 1: Web search              → Free, 2-3 seconds
         ↓ Need depth?
Level 2: Tavily Deep Research    → API credits, 30-120 seconds
```

### 📚 Knowledge System — 5-Layer Knowledge Stack

```
L1: file:// resource        → Loaded at startup (AGENTS.md, INDEX.md)
L2: skill:// resource       → Metadata at startup, full text on demand
L3: INDEX.md manual routing  → Question → index → topic → source doc
L4: knowledgeBase resource   → Semantic search index (millions of tokens)
L5: knowledge tool           → Cross-session memory (experimental)
```

## 📦 Skills — Curated from the Best

Skills are organized into 4 tiers:

### Core — Workflow Essentials (auto-invoked)

| Skill | When It Activates |
|-------|-------------------|
| `brainstorming` | Before any creative work — explores intent before implementation |
| `writing-plans` | When you have a spec — structured, reviewable plan |
| `executing-plans` | When you have a plan — executes with review checkpoints |
| `systematic-debugging` | When hitting a bug — root cause analysis, not random fixes |
| `code-review-expert` | When reviewing git changes — SOLID, security, actionable improvements |
| `verification-before-completion` | Before claiming "done" — evidence before assertions |

### Domain — Specialized Experts (auto-invoked when relevant)

| Skill | When It Activates |
|-------|-------------------|
| `java-architect` | When building Java/Spring Boot apps — enterprise patterns, WebFlux, JPA |
| `mermaid-diagrams` | When visualizing architecture — class, sequence, flow, ER diagrams |
| `research` | When information is needed — multi-level search with cost awareness |

### Utility — User-Invoked Tools

| Skill | When It Activates |
|-------|-------------------|
| `humanizer` | When editing text — removes AI-generated writing patterns |
| `doc-coauthoring` | When writing docs/proposals — structured co-authoring workflow |
| `writing-clearly-and-concisely` | When writing prose — Strunk's rules for stronger writing |
| `find-skills` | When looking for capabilities — discovers installable skills |
| `skill-creator` | When creating new skills — guides skill design and structure |
| `using-git-worktrees` | When starting feature work — isolated parallel development |
| `finishing-a-development-branch` | When implementation is complete — merge, PR, or cleanup |

### Framework Core

| Skill | When It Activates |
|-------|-------------------|
| `self-reflect` | When you correct the agent — captures and persists the learning |
| `dispatching-parallel-agents` | When facing 2+ independent tasks — parallel execution |
| `subagent-driven-development` | When executing plans — delegate to subagents |
| `test-driven-development` | When implementing features — tests first, then code |
| `requesting-code-review` | When work is done — structured self-review before merge |
| `receiving-code-review` | When getting feedback — technical rigor, not blind agreement |

## Project Structure

```
.
├── CLAUDE.md                              # Layer 1: Working memory (Claude Code)
├── AGENTS.md                              # Layer 1: Working memory (Kiro CLI)
├── .claude/
│   ├── hooks/                             # Layer 0: Hook scripts (unified source)
│   │   ├── security/
│   │   │   ├── block-dangerous-commands.sh
│   │   │   ├── block-secrets.sh
│   │   │   └── scan-skill-injection.sh
│   │   ├── quality/
│   │   │   ├── verify-completion.sh       # Stop hook (B+A+C 3-phase)
│   │   │   ├── auto-test.sh              # PostToolUse auto-test
│   │   │   ├── auto-lint.sh
│   │   │   ├── enforce-skill-chain.sh
│   │   │   └── reviewer-stop-check.sh
│   │   ├── autonomy/
│   │   │   ├── context-enrichment.sh      # UserPromptSubmit
│   │   │   ├── auto-approve-safe.sh       # PermissionRequest (CC only)
│   │   │   └── inject-subagent-rules.sh   # SubagentStart (CC only)
│   │   ├── lifecycle/
│   │   │   ├── session-init.sh
│   │   │   └── session-cleanup.sh
│   │   └── _lib/
│   │       ├── common.sh                  # Shared functions
│   │       ├── patterns.sh               # Shared regex patterns
│   │       └── llm-eval.sh              # Unified LLM evaluation library
│   ├── rules/                             # Layer 2: Modular rules
│   │   ├── security.md
│   │   ├── git-workflow.md
│   │   └── code-quality.md
│   ├── settings.json                      # Claude Code hook registration
│   └── skills/                            # Layer 3: Skills (symlink source)
├── .kiro/
│   ├── agents/                            # Layer 4: Subagent configs
│   │   ├── default.json
│   │   ├── researcher.json
│   │   ├── implementer.json
│   │   ├── reviewer.json
│   │   ├── debugger.json
│   │   └── prompts/
│   ├── hooks/ → ../.claude/hooks/         # Symlink to unified hooks
│   ├── skills/ → ../.claude/skills/       # Symlink to unified skills
│   └── rules/
├── knowledge/                             # Layer 5: Persistent memory
│   ├── INDEX.md                           # Knowledge routing table
│   └── lessons-learned.md                 # Episodic memory
├── docs/
│   ├── designs/                           # Design docs
│   ├── plans/                             # Implementation plans
│   ├── research/                          # Research artifacts
│   ├── decisions/                         # Architecture decision records
│   └── completed/                         # Archived completion criteria
└── tools/
    └── init-project.sh                    # Bootstrap new projects
```

## Compatibility

| Tool | Config | Hooks | Skills | Subagents | Status |
|------|--------|-------|--------|-----------|--------|
| **Claude Code** | `CLAUDE.md` | ✅ 14 events, agent/prompt/command types | ✅ | ✅ Full | ~100% capability |
| **Kiro CLI** | `AGENTS.md` | ✅ 5 events, command type only | ✅ | ✅ With constraints | ~91% capability |

Kiro CLI's ~9% gap is concentrated in: Stop hook cannot block agent from stopping, no native LLM hook evaluation (bridged by `llm-eval.sh`), subagents lack `web_search`/`code` tools.

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

### Option 2: Add to existing project

```bash
git clone https://github.com/KaimingWan/oh-my-claude-code.git /tmp/omcc
/tmp/omcc/tools/init-project.sh ./my-project "My Project"
```

### Option 3: Cherry-pick

| Want | Copy |
|------|------|
| Just the 6-layer structure | `CLAUDE.md` + `.claude/rules/` + `.claude/hooks/` |
| Just the hooks | `.claude/hooks/` + `.claude/settings.json` |
| Just self-learning | `.kiro/skills/self-reflect/` |
| Just knowledge system | `knowledge/` |
| Just subagents | `.kiro/agents/` |

### Troubleshooting

**Kiro CLI: "user defined default not found"**

```bash
mkdir -p ~/.kiro/agents
echo '{"name":"default","description":"Global default","tools":["*"],"allowedTools":["*"]}' > ~/.kiro/agents/default.json
```

## Design Principles

1. **Compound over time** — Every session makes the next one better
2. **Persist everything valuable** — Chat is ephemeral, files are forever
3. **Closed-loop evolution** — Corrections → persistent rules → fewer corrections
4. **Code over prose** — Hooks enforce, words suggest
5. **Progressive disclosure** — 6 layers, each loaded only when needed
6. **Verification first** — Evidence before claims, always
7. **Plan as living document** — Plans are the single source of truth, not conversations

## Contributing

PRs welcome! The bar for CLAUDE.md additions is intentionally high — if it can be a hook, make it a hook. If it's not needed every conversation, it belongs in a deeper layer.

## License

MIT
