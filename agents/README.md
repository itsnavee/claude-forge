# Agent Personalities

Reusable agent identities for sub-agents. Load any of these into a sub-agent by reading the file and adopting the identity before doing work.

---

## Directory Structure

```
agents/
├── debate/           # Adversarial trio — always used together
│   ├── skeptic.md
│   ├── believer.md
│   └── referee.md
├── reviewers/        # Evaluate code, docs, security
│   ├── code.md
│   ├── doc.md
│   └── security.md
├── specialists/      # Domain expertise
│   ├── architect.md
│   ├── platform.md
│   └── frontend.md
├── scouts/           # External research
│   └── github.md
└── workers/          # Task execution
    └── crawler.md
```

## All Agents

| Agent | Path | Model | Effort | Role | Verdict Format |
|-------|------|-------|--------|------|----------------|
| **Skeptic** | `debate/skeptic.md` | sonnet | high | Assumes everything is wrong; finds race conditions, edge cases, security holes | BLOCK / CONDITIONAL / PASS WITH CAVEATS |
| **Believer** | `debate/believer.md` | sonnet | high | Argues for the approach with evidence; pushes back on nitpicks | DEFEND / CONCEDE / PARTIAL |
| **Referee** | `debate/referee.md` | sonnet | max | Final arbiter; rules on evidence, not opinion | BLOCK / FIX SOON / MOVE ON |
| **Code Reviewer** | `reviewers/code.md` | sonnet | high | 10-dimension code review: correctness, security, error handling, concurrency, complexity | BLOCK / FIX SOON / SHIP WITH CAVEATS |
| **Doc Reviewer** | `reviewers/doc.md` | haiku | medium | Accuracy, completeness, verifiability, consistency, actionability | BLOCK / REVISE / SHIP |
| **Security Reviewer** | `reviewers/security.md` | sonnet | high | OWASP A1–A10, STRIDE threat modeling, SAST recommendations | CRITICAL / HIGH / MEDIUM / LOW |
| **Architect** | `specialists/architect.md` | opus | max | Data models, abstractions, service boundaries, scale, failure modes | SOUND / ACCEPTABLE / NEEDS REWORK / FUNDAMENTALLY WRONG |
| **Platform** | `specialists/platform.md` | sonnet | high | 3-2-1 backup, DR, cron durability, cost bounds, operational continuity | RESILIENT / AT RISK / FRAGILE / CRITICAL |
| **Frontend** | `specialists/frontend.md` | sonnet | high | Core Web Vitals, bundle size, rendering strategy, React patterns | PERFORMANT / ACCEPTABLE / NEEDS WORK / CRITICAL |
| **GitHub Scout** | `scouts/github.md` | haiku | low | GitHub repo researcher using gh CLI; metadata, READMEs, file trees | JSON structured results |
| **Crawler** | `workers/crawler.md` | haiku | low | Web crawler via Cloudflare Browser Rendering API; extracts structured content | Crawl report with content map |

---

## Debate Trio

The **Skeptic → Believer → Referee** sequence is the standard debate pattern:

1. **Skeptic** reviews first — adversarial, finds everything wrong
2. **Believer** responds — argues for the approach with evidence, concedes real problems
3. **Referee** rules — reads both, issues binding decisions, produces action items

Use this pattern when a decision has real stakes and you want to avoid both over-blocking and blind spots.

---

## Planning Doc Review

Every agent in `reviewers/` and `specialists/` has a `## Planning Doc Review` section that defines what gaps to look for in planning docs.

The `/my-review-docs` skill orchestrates all agents against a project's planning docs in parallel, then aggregates findings by priority.

---

## Context Awareness

All agents must follow these rules:
- **Effort level**: Use the effort level specified in the agent's header when dispatching. Low = scouts/workers, medium = doc review, high = reviewers/specialists, max = referee/architect.
- **Context self-management**: If your context exceeds 500K tokens, summarize findings so far and return partial results rather than degrading silently. Do not wait for compaction to save you.

---

## Usage

To load an agent identity in a sub-agent prompt:

```
Read ~/.claude/agents/debate/skeptic.md and adopt that identity.
Then review the following: [paste content or provide file paths]
```

Or reference via `/my-review-docs`, `/my-agent-teams`, `/my-pr-review`, or `/my-code-gaps-fix` which handle orchestration automatically.
