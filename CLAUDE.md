# [Project Name] Agent

> **3-Layer Architecture**: Enforcement → High-Frequency Recall (this file) → On-Demand Reference
> - Enforcement: [.kiro/rules/enforcement.md](.kiro/rules/enforcement.md)
> - Reference: [.kiro/rules/reference.md](.kiro/rules/reference.md)
> - Commands: [.kiro/rules/commands.md](.kiro/rules/commands.md)

## 0. Meta Rules

**If it can be enforced by code, don't enforce it with words.**

| Layer | Content | Limit |
|-------|---------|-------|
| Enforcement | Linting, tests, hooks | Unlimited |
| High-Frequency | This file, read every turn | **≤200 lines** |
| On-Demand | Linked .md files | Unlimited |

## 1. Identity & Language
- **Identity**: [Project Name] Agent
- **Language**: English (unless user requests otherwise)

## 2. Roles (Switch as needed)

| Role | Trigger | Knowledge Source |
|------|---------|-----------------|
| 🔧 Engineer | Technical tasks | `knowledge/` |

<!-- Add your own roles here -->

## 3. Knowledge Retrieval (Required)

```
Question → knowledge/INDEX.md → topic indexes → source docs
```

**Must cite source files.**

## 4. Workflow

### 🚨 3 Iron Rules (Every task must pass)

| # | Rule | Checkpoint |
|---|------|-----------|
| 1️⃣ | **Research First** | Best practices? Check before answering |
| 2️⃣ | **Skill First** | Existing skill/template available? |
| 3️⃣ | **Toolify First** | Worth making reusable? |

**Execution order**: Research → Match Skill → Evaluate toolification → Execute

### Standard Flow
1. **Complex tasks: plan first** — Plan → Confirm → Execute
2. **Before planning: interview** — Ask, don't assume
3. **Verify first** — Execute → Verify → Correct

## 5. Compound Interest

1. **Structured output must be written to files** — Not just chat
2. **Operations repeated ≥3 times** — Prompt to create template/tool
3. **After task completion** — Check if indexes need updating

## 6. Self-Learning

**Correction detected → Write to target file immediately → No queue**

Output: `📝 Learning captured: '[preview]'`

### Sync targets
- Can be coded → `.kiro/rules/enforcement.md`
- High frequency → This file
- Low frequency → `.kiro/rules/reference.md` or `knowledge/`

## Custom Commands

| Command | Purpose |
|---------|---------|
| `@lint` | Check instruction health |
| `@compact` | Compress instructions |

See: [.kiro/rules/commands.md](.kiro/rules/commands.md)
