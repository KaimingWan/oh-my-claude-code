---
name: research
description: "Multi-level research with automatic fallback. Web search → Deep research API. Use when you need comprehensive research grounded in web data."
---

# Research Skill — Multi-Level Search

## Search Level Strategy

Always use the lowest level that can answer the question:

| Level | Tool | Use Case | Cost |
|-------|------|----------|------|
| 0 | Built-in knowledge | Common concepts, basics | Free |
| 1 | `web_search` | Quick verification, simple queries | Free |
| 2 | Tavily Research API | Deep research, competitive analysis | API credits |

**Rule**: If Level 0 or 1 can answer it, don't use Level 2.

**Don't need research**: Common knowledge, already in `knowledge/`, answerable from built-in knowledge.

## Level 2: Tavily Research API

### Prerequisites

Get your API key at https://tavily.com (1000 free credits/month)

Set environment variable:
```bash
export TAVILY_API_KEY="tvly-your-key-here"
```

Or add to your agent config:
```json
{
  "env": {
    "TAVILY_API_KEY": "tvly-your-key-here"
  }
}
```

### Usage

```bash
./scripts/research.sh '{"input": "your research query"}' [output_file]

# Quick research
./scripts/research.sh '{"input": "quantum computing trends"}'

# Deep research
./scripts/research.sh '{"input": "AI agents comparison", "model": "pro"}'

# Save to file
./scripts/research.sh '{"input": "market analysis", "model": "pro"}' ./report.md
```

### Model Selection

| Model | Use Case | Speed |
|-------|----------|-------|
| `mini` | Single topic, targeted | ~30s |
| `pro` | Multi-angle, comprehensive | ~60-120s |
| `auto` | API chooses based on complexity | Varies |

**Rule of thumb**: "what does X do?" → mini. "X vs Y vs Z" → pro.

### Structured Output

```bash
./scripts/research.sh '{
  "input": "fintech startups 2025",
  "model": "pro",
  "output_schema": {
    "properties": {
      "summary": {"type": "string", "description": "Executive summary"},
      "companies": {"type": "array", "items": {"type": "string"}}
    },
    "required": ["summary"]
  }
}'
```

### Citation Formats

Supported: `numbered` (default), `mla`, `apa`, `chicago`

```bash
./scripts/research.sh '{"input": "climate impacts", "citation_format": "apa"}'
```
