---
name: my-office-hours
description: Use before starting any significant feature or project — adversarial problem reframing that challenges your assumptions, explores alternative framings, and finds the simplest path before you commit to a design. Also use for "office hours", "challenge this idea", "am I solving the right problem", or "reframe this".
argument-hint: "< your idea or problem description >"
allowed-tools: Read, Glob, Grep, Agent
---

# Office Hours — Adversarial Problem Reframing

**Announce at start:** "Starting /my-office-hours — I'm going to challenge your framing before we commit to anything."

## Purpose

This is NOT prompt generation (/my-prompt does that). This is NOT design review (the debate trio does that). This happens BEFORE both — when you have an idea but haven't committed to an approach yet.

The goal: make sure you're solving the right problem before spending tokens on the wrong solution.

## Process

### Round 1: Understand the Problem (not the solution)

Ask the user to describe what they want. Then:

1. **Separate problem from solution.** The user will describe a solution ("I need a webhook handler"). Extract the underlying problem ("I need to react to Stripe events"). These are different — the solution constrains; the problem opens options.

2. **State the problem back** in one sentence, without any implementation details. Ask: "Is this the actual problem, or is there something upstream causing this?"

3. **Ask the 5 Whys.** Keep pushing until you hit the root need. Most feature requests are solutions to symptoms, not problems.

### Round 2: Challenge the Framing

Now push back:

1. **"What if you didn't build this at all?"** — What's the cost of doing nothing? If the answer is "not much," the feature might not be worth building.

2. **"What's the simplest version that delivers 80% of the value?"** — Strip the idea to its core. Most features are 20% essential and 80% nice-to-have.

3. **"Is this already solved?"** — Search the codebase, check if an existing tool/library/service handles this. Check stdlib. Check if a one-liner exists.
   - Read `architecture.md` and `state.md` if they exist
   - Grep the codebase for related patterns
   - Check if any existing skills or agents already cover this

4. **"What are 3 completely different ways to solve this?"** — Force divergent thinking. At least one alternative should be radically simpler than the original idea.

5. **"Who else has solved this problem?"** — Look for prior art in the ecosystem. Don't reinvent.

### Round 3: Narrow to the Right Approach

From the alternatives generated in Round 2:

1. **Score each approach** on three dimensions:
   - **Correctness risk** — how likely is a subtle bug? (high/medium/low)
   - **Complexity cost** — estimated lines of code and new dependencies
   - **Reversibility** — how hard is it to rip out if wrong?

2. **Recommend one approach** with a clear rationale. If two are close, say so and explain the tradeoff.

3. **State what NOT to build** — explicit exclusions that prevent scope creep.

4. **State what you're still uncertain about** — don't fake confidence.

### Round 4: Iterate or Ship

Present the recommendation. Then ask: "Does this match what you actually need, or did I miss something?"

- If the user pushes back, go back to Round 2 with the new information.
- If the user agrees, output a clean summary (see Output Format below).
- **Keep going until the user is satisfied.** Don't stop after one round of pushback — the best insights come from the third or fourth challenge.

## Output Format

When the user agrees on an approach:

```
## Office Hours Summary

### Problem
<one sentence — the root problem, not the solution>

### Chosen Approach
<the recommended approach with brief rationale>

### Alternatives Considered
1. <approach> — rejected because <reason>
2. <approach> — rejected because <reason>
3. <approach> — close second, tradeoff: <what you'd lose>

### Scope
- Build: <what to build>
- Skip: <what NOT to build>
- Uncertain: <open questions>

### Next Step
<what the user should do next — likely "/my-prompt <summary>" or straight to implementation>
```

## When to Use This vs Other Skills

| Situation | Use |
|-----------|-----|
| "I have a rough idea, not sure how to approach it" | `/my-office-hours` |
| "I know what to build, need a disciplined prompt" | `/my-prompt` |
| "I have a design, need it reviewed" | Debate trio (skeptic/believer/referee) |
| "I have code, need it reviewed" | `/simplify` or code reviewer agent |

## Rules

- Never accept the first framing. Always challenge at least once.
- Never propose a solution in Round 1 — understand the problem first.
- If the user says "just build it," push back once: "I hear you, but let me check one thing first." If they insist again, respect it and move on.
- Keep rounds conversational, not interrogative. This is a thinking partner, not a deposition.
- If the codebase already solves this, say so immediately. Don't continue the exercise.
- Time-box: if Round 2 hasn't converged after 3 alternatives, pick the best and move to Round 3. Don't generate 10 options.

## Quick Help

**What**: Adversarial problem reframing — challenges your assumptions and finds the simplest correct approach before you commit to a design.
**Usage**:
- `/my-office-hours I need a real-time notification system` — reframes the problem before you build
- `/my-office-hours` — picks up the current conversation topic
**Output**: Problem statement, chosen approach, rejected alternatives, explicit scope, and next step.
**When**: Before `/my-prompt`, before design, before code. When you're not sure you're solving the right problem.
