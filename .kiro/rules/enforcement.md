# Enforcement Layer

> If it can be enforced by code, don't enforce it with words.

## Implemented

| Rule | Implementation | Status |
|------|---------------|--------|
| 3 Iron Rules reminder | `.kiro/hooks/three-rules-check.sh` (userPromptSubmit) | ✅ |
| Skill chain enforcement | `.kiro/hooks/enforce-skill-chain.sh` (userPromptSubmit) | ✅ |
| Anti-hallucination guard | `.kiro/hooks/enforce-research.sh` (preToolUse) | ✅ |
| Persistence check | `.kiro/hooks/check-persist.sh` (stop) | ✅ |
| Lessons-learned check | `.kiro/hooks/enforce-lessons.sh` (stop) | ✅ |
| Dangerous command blocker | `.kiro/hooks/block-dangerous-commands.sh` (preToolUse) | ✅ |
| Secret leak blocker | `.kiro/hooks/block-secrets.sh` (preToolUse) | ✅ |

## To Implement

| Rule | Planned Implementation | Priority |
|------|----------------------|----------|
| Markdown lint | `.markdownlint.json` | P2 |
| Index integrity | `tests/test_index_integrity.py` | P2 |

## Adding New Rules

1. Confirm the rule can be enforced by code
2. Choose implementation (linting / test / hook)
3. Implement and test
4. Move from "To Implement" to "Implemented"
