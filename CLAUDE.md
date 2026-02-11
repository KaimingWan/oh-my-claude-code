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

## 4. Security Red Lines (Non-negotiable)

🚫 **NEVER execute without explicit user confirmation:**
- `rm`, `rmdir`, `shred` — use `mv ~/.Trash/` instead
- `git checkout` (without `-b`) — stash first, explain what will be lost
- `git reset --hard`, `git clean -f` — show diff/list first
- `git stash drop`, `git branch -D` — explain consequences first
- `sudo`, `chmod -R 777`, `chown -R` — explain why needed
- Piping curl/wget to shell — never

**Enforced by**: `.kiro/hooks/block-dangerous-commands.sh` (preToolUse)

## 5. Workflow

### 🚨 3 Iron Rules (Every task must pass)

| # | Rule | Checkpoint |
|---|------|-----------|
| 1️⃣ | **Research First** | Best practices? Check before answering |
| 2️⃣ | **Skill First** | Existing skill/template available? |
| 3️⃣ | **Toolify First** | Worth making reusable? |

**Execution order**: Research → Match Skill → Evaluate toolification → Execute

### Mandatory Skill Chains (Enforced by `.kiro/hooks/enforce-skill-chain.sh`)

| Intent | Required Skills (in order) |
|--------|---------------------------|
| 🏗️ Planning/Design | brainstorming → writing-plans → lessons-learned check |
| ✅ Completion/Merge | verification-before-completion → code-review-expert → lessons-learned update |
| 🐛 Debugging | systematic-debugging → lessons-learned check |

**Skip = violation. Hook will remind you.**

### Product Context (Optional)

If `knowledge/product/PRODUCT.md` exists and is non-empty, read it before feature/refactor/plan work.

### Standard Flow
1. **Complex tasks: plan first** — Plan → Confirm → Execute
2. **Before planning: interview** — Ask, don't assume
3. **Verify first** — Execute → Verify → Correct
4. **After every task** — Check & update `knowledge/lessons-learned.md`

## 6. Compound Interest

1. **Structured output must be written to files** — Not just chat
2. **Operations repeated ≥3 times** — Prompt to create template/tool
3. **After task completion** — Check if indexes need updating

## 7. Self-Learning

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
