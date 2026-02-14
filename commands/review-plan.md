Find the latest .md file in docs/plans/ (by modification time). Dispatch a reviewer subagent (agent_name: "reviewer") with this query:

"Review the plan at docs/plans/<filename>. Read the plan's Goal section for context. Find gaps, risks, and missing steps. Output: Strengths / Weaknesses / Missing / Verdict: APPROVE or REQUEST CHANGES (with required fixes). Write your conclusions into the plan's ## Review section."

Report the reviewer's verdict to me. If APPROVE, ask me to confirm before executing. If REQUEST CHANGES, list what needs fixing.
