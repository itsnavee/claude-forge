---
name: my-agent-teams
description: Use when facing a complex task that benefits from multiple specialized agents working in parallel — spawns, delegates, tracks status, and collects results. Also use when the user says "use agents", "multi-agent", or "parallelize this".
argument-hint: "< feature | debug | review | custom > [description]"
allowed-tools: Read, Glob, Grep, Bash(git:*), Agent
---

# Agent Teams — Multi-Agent Coordination

Spawn coordinated agent teams for tasks too large or complex for a single agent. Each team has a lead who delegates, tracks, and synthesizes.

## Quick Help

**What**: Spin up a coordinated team of agents with a lead, workers, and a reviewer. Tracks progress and synthesizes results.
**Usage**:
- `/my-agent-teams feature Add webhook signature verification to all endpoints` — feature team (architect + implementers + reviewer)
- `/my-agent-teams debug Payment webhook failing silently for Stripe test events` — debug team (investigator + reproducer + fixer)
- `/my-agent-teams review src/api/` — review team (code-reviewer + security-reviewer + architect)
- `/my-agent-teams custom 3 agents: one reads all DB schemas, one reads all API routes, one reads all tests — synthesize gaps` — custom team
**Output**: Synthesized report from team lead with individual agent findings merged.

## Team Templates

### Feature Team

| Role | Agent Identity | Model | Task |
|------|---------------|-------|------|
| **Lead: Architect** | `specialists/architect.md` | opus | Break feature into tasks, assign to implementers, review integration |
| **Worker 1: Implementer** | Default | sonnet | Implement task 1 from architect's breakdown |
| **Worker 2: Implementer** | Default | sonnet | Implement task 2 (parallel with Worker 1) |
| **Reviewer** | `reviewers/code.md` | sonnet | Review all implementations against acceptance criteria |

### Debug Team

| Role | Agent Identity | Model | Task |
|------|---------------|-------|------|
| **Lead: Investigator** | `debate/skeptic.md` | sonnet | Trace the bug — read logs, find root cause, form hypothesis |
| **Worker 1: Reproducer** | Default | sonnet | Write a minimal reproduction (test case that fails) |
| **Worker 2: Fixer** | Default | sonnet | Implement fix based on investigator's hypothesis |
| **Reviewer** | `reviewers/code.md` | haiku | Verify fix is correct and doesn't introduce regressions |

### Review Team

| Role | Agent Identity | Model | Task |
|------|---------------|-------|------|
| **Lead: Code Reviewer** | `reviewers/code.md` | sonnet | Full 10-dimension code review |
| **Worker 1: Security** | `reviewers/security.md` | sonnet | Security-focused review with STRIDE |
| **Worker 2: Architect** | `specialists/architect.md` | opus | Architecture and design review |
| **Synthesizer** | `debate/referee.md` | sonnet | Deduplicate findings, resolve conflicts, final verdict |

### Custom Team

User specifies the number of agents and their tasks. Lead is auto-assigned as the first agent.

## Steps

### 1. Select or Build Team

If the user specifies a template (`feature`, `debug`, `review`), use it. Otherwise parse the custom description to determine:
- How many agents are needed
- What each agent's focus is
- Which existing agent identities to load (from `~/.claude/agents/`)
- Who is the lead (synthesizes results)

### 2. Prepare Context

Before spawning agents, gather shared context they all need:
- Read relevant files (the lead determines which)
- Get git status and recent history if relevant
- Summarize the task and acceptance criteria

### 3. Dispatch Agents in Parallel

Launch all worker agents simultaneously using the Agent tool. Each agent gets:
- The shared context from step 2
- Their specific task assignment
- Their agent identity (if loading from `~/.claude/agents/`)
- The correct **model tier** (see Model-Tier Dispatch below)
- Instructions to return structured output

**Critical**: All workers run in parallel. Do NOT wait for one to finish before launching the next.

### Model-Tier Dispatch

Match model tier to task complexity. Use the `model` parameter on the Agent tool:

| Tier | Use for | Cost |
|------|---------|------|
| **haiku** | Verification, formatting, grep searches, simple transforms, scouts (github) | 10-20x cheaper |
| **sonnet** | Standard implementation, research, coding, code review, debate agents | Default |
| **opus** | Architecture decisions, strategy, complex judgment, orchestration | Most expensive |

**Agent → Tier mapping:**

| Agent | Recommended Tier |
|-------|-----------------|
| debate/skeptic | sonnet |
| debate/believer | sonnet |
| debate/referee | sonnet |
| reviewers/code | sonnet |
| reviewers/doc | haiku |
| reviewers/security | sonnet |
| scouts/github | haiku |
| specialists/architect | opus |
| specialists/frontend | sonnet |
| specialists/platform | sonnet |
| workers/crawler | haiku |
| Default implementer | sonnet |
| Verification/formatting | haiku |

**Example dispatch:**
```
Agent(prompt="...", model="haiku")   # for scouts, verification
Agent(prompt="...", model="sonnet")  # for implementation, review
Agent(prompt="...", model="opus")    # for architecture decisions
```

### 4. Collect and Synthesize

Once all agents return:
1. The lead/synthesizer reviews all outputs
2. Deduplicates findings (same issue from multiple agents = one finding)
3. Resolves conflicts (if agents disagree, the lead makes the call — or escalates to referee)
4. Produces a unified report

### 5. Output Format

```
## Team Report: [task description]
Team: [template name or "custom"] | Agents: [N] | Duration: [time]

### Team Composition
| Role | Identity | Status |
|------|----------|--------|

### Synthesized Findings
[merged, deduplicated results from all agents — sorted by priority]

### Conflicts Resolved
[where agents disagreed and how it was resolved]

### Next Steps
[actionable items from the team's work]
```

## Gotchas

- All subagents default to Opus — use `model: haiku` for verification/formatting agents to cut costs 10-20x
- Subagent results held only in memory get erased by context compaction — write results to disk if processing >3 agents
- Background agents complete asynchronously — don't poll for results, wait for the notification

## Rules

- Always use existing agent identities from `~/.claude/agents/` when a matching personality exists
- All worker agents run in parallel — never sequential unless there's a true dependency
- The lead/synthesizer agent always runs AFTER workers complete
- Maximum team size: 6 agents (beyond that, split into sub-teams)
- Each agent must return structured output — reject freeform prose
- If an agent fails or returns garbage, note it in the report — don't silently drop it
- Custom teams must have at least 2 agents (otherwise just use the agent directly)
- Never spawn agents for tasks a single agent could handle — push back if the task is simple
