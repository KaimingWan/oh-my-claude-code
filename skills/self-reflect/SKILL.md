---
name: self-reflect
description: "Self-learning system — detects corrections and writes to target files immediately. No queue delay."
---

# Self-Reflect — Agent Self-Learning System

## Core Principle

**Correction detected → Write to target file immediately → No queue**

## Sync Targets (3-Layer Architecture)

| Rule Type | Target File |
|-----------|-------------|
| Code-enforceable | `.kiro/rules/enforcement.md` |
| High-frequency | `CLAUDE.md` / `AGENTS.md` |
| Low-frequency | `.kiro/rules/reference.md` or `knowledge/` |
| Mistakes | `knowledge/lessons-learned.md` |

## Trigger Patterns

**High confidence (90%)**:
- `remember:` / `always:`
- `don't ... unless`
- `I told you`

**Medium confidence (80%)**:
- `no, use X` / `not X, use Y`
- `you missed` / `why didn't you`
- `research first` / `verify first`

**Implicit negation (75%)**:
- `not good enough`
- `you forgot`
- `you failed to`

**Positive feedback (70%, also captured)**:
- `perfect!` / `exactly right`
- `great approach` / `that's what I wanted`
- `keep doing this`

### Exclusion Patterns (Don't capture)
- Questions ending with `?`
- Requests starting with `please` / `help me`
- Error reports (`error`, `failed`)
- Messages over 300 characters (likely context, not correction)

## On Detection

1. Confirm: `📝 Learning captured: '[preview]'`
2. **Write to target file immediately** (no queue)
3. Continue answering the user's question

## Target Selection Logic

| Indicator | Target |
|-----------|--------|
| Model names (`gpt-`, `claude-`, `gemini-`) | Global (`~/.kiro/AGENTS.md`) |
| Format/naming/style rules | `enforcement.md` |
| Templates, SOPs, workflows | `reference.md` |
| Everything else | `CLAUDE.md` / `AGENTS.md` |

## Commands

| Command | Purpose |
|---------|---------|
| `/reflect-skills` | Discover repeated patterns, generate skills |

## Examples

### Correction → Immediate Learning
```
User: no, use gpt-5.1 not gpt-5
Agent: 📝 Learning captured: 'use gpt-5.1 not gpt-5'
       OK, switching to gpt-5.1.
```

### Constraint Rule
```
User: don't add comments unless I ask
Agent: 📝 Learning captured: 'don't add comments unless I ask'
       Got it, no comments unless requested.
```
