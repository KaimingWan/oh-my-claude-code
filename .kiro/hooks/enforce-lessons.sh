#!/bin/bash
# Enforce lessons check — stop hook
# Reminds agent to check and update lessons-learned after every task

cat << 'EOF'
📝 Lessons Check (MANDATORY before closing):
1. Read knowledge/lessons-learned.md
2. Did anything go wrong? → Add to Mistakes table
3. Did something work well? → Add to Wins table
4. Can a rule be extracted? → Add to Rules Extracted, then enforce via code
EOF
