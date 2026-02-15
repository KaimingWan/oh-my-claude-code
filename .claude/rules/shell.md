# Shell Rules
# Layer: Agent Rule (top-level principles + operational rules)
# Maintained by: humans only (hook enforced)
# Boundary: universal rules, not project-specific learnings

1. JSON = jq，无条件无例外。禁止 sed/awk/grep 修改 JSON。[hook: block-sed-json]
2. macOS 用 stat -f，禁止 stat -c（GNU-only）。
3. grep -c 无匹配时 exit 1 但仍输出 0，不要和 || echo 0 组合。用 || true 或 wc -l。
4. shell 脚本生成前确认目标平台，BSD vs GNU 工具链差异。
5. 结构化数据用结构化工具：JSON→jq, YAML→yq, XML→xmlstarlet。
