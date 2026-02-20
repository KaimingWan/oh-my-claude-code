import pathlib
plan = pathlib.Path("plan_content.md").read_text()
pathlib.Path("docs/plans/2026-02-21-hook-governance.md").write_text(plan)
print(f"Written {len(plan)} bytes")
