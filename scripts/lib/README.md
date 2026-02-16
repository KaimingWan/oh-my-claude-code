# scripts/lib/ — Python Shared Library

Used by: `scripts/ralph_loop.py`, `scripts/generate_configs.py`
NOT used by: `hooks/**/*.sh` (hooks are bash, latency-sensitive)

## Boundary Rule

Hooks (bash, <5ms) ←→ file protocol ←→ Scripts (Python, complex logic)

Never: hooks importing Python | scripts sourcing bash
