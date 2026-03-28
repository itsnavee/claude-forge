---
name: my-adversarial-review
description: Use when code needs rigorous review before shipping — spawns skeptic/believer/referee agents in iterative rounds until findings converge to nitpicks. Use after implementing features, before merging PRs, or when the user asks for a "thorough review", "adversarial review", or "tear this apart".
argument-hint: "< file path | directory | branch >"
gate:
  type: cooldown
  duration: 25m
  reason: "Spawns 3+ agents per round across multiple iterations. Re-running on unchanged code burns significant tokens with no new findings."
---

# /my-adversarial-review — Iterative Adversarial Code Review

Spawns three adversarial agents (Skeptic, Believer, Referee) in iterative rounds. Each round narrows findings until the Skeptic can only find nitpicks — that's the convergence signal.

## Behavior

### 1. Identify Scope

Determine what to review:
- Specific files (from user request or recent changes)
- A PR diff (`git diff main...HEAD`)
- A feature or module

Gather the code to review by reading relevant files.

### 2. Round 1 — Full Adversarial Pass

Launch 3 parallel subagents:

**Skeptic** (load `~/.claude/agents/debate/skeptic.md`):
> "Review this code assuming everything is wrong. Find: security holes, race conditions, edge cases, logic errors, performance issues, missing error handling, incorrect assumptions. Score each finding by severity (Critical/High/Medium/Low). You get penalized for missing real bugs."

**Believer** (load `~/.claude/agents/debate/believer.md`):
> "Defend this code. For each potential concern, argue why it's correct or acceptable. Push back on nitpicks. Cite specific evidence (tests, type safety, framework guarantees). You get penalized for defending genuinely broken code."

**Referee** (load `~/.claude/agents/debate/referee.md`):
> "Given the Skeptic's findings and Believer's rebuttals, rule on each: MUST FIX (ship-blocking), SHOULD FIX (improves quality), or DISMISS (nitpick/false positive). Provide reasoning for each ruling."

### 3. Convergence Check

After each round, check the Referee's output:

- **If any MUST FIX items exist** → fix them, then run another round with the updated code
- **If only SHOULD FIX and DISMISS** → one more round to verify the SHOULD FIX items
- **If all DISMISS or only cosmetic SHOULD FIX** → **converged** — stop iterating

**Maximum 3 rounds.** If not converged after 3 rounds, report remaining items and let the user decide.

### 4. Report

After convergence:

```
Adversarial Review — <scope>
═══════════════════════════
Rounds: <N> (converged | max rounds reached)

MUST FIX (round 1):
  ✓ [Fixed] <description> — <file:line>
  ✓ [Fixed] <description> — <file:line>

SHOULD FIX:
  → <description> — <file:line> (Referee: "improves readability")
  → <description> — <file:line> (Referee: "edge case unlikely but possible")

DISMISSED:
  ✗ <Skeptic concern> — Referee: "<reason for dismissal>"

Confidence: High | Medium
Remaining risk: <what could still be wrong>
```

## Gotchas

- Agent personalities must be loaded fresh each round — don't let context from previous rounds bias the agents
- The Believer should defend with evidence (tests, types, framework guarantees), not just "it looks fine"
- The Referee must give reasoning for each ruling — "DISMISS" without explanation is not acceptable
- Code fixes between rounds should be minimal — fix only MUST FIX items, don't refactor during review
- If the same finding oscillates between MUST FIX and DISMISS across rounds, escalate to the user

## Rules

- Always load agent personality files before dispatching — don't improvise personas
- Run Skeptic and Believer in parallel for speed; Referee runs after both complete
- Each subagent receives ONLY the code being reviewed + the previous round's findings (if applicable)
- Never auto-merge after review — the user decides
- State remaining risk honestly — "no findings" doesn't mean "no bugs"
- Maximum 3 rounds to prevent infinite loops
