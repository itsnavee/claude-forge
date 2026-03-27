---
name: my-autoresearch
description: Use when you want to improve a skill's quality automatically — runs iterative self-improvement loop with binary checklist scoring. Adapts Karpathy's autoresearch method. Also use for "improve this skill", "optimize skill", or "autoresearch".
argument-hint: "< skill-name > [max-iterations]"
---

<!-- Pattern: Pipeline -->

# /my-autoresearch — Iterative Skill Self-Improvement

Runs a skill against test inputs, scores output against a binary yes/no checklist, makes one targeted prompt edit per iteration, keeps or reverts based on pass rate delta. Stops at 95%+ three consecutive times or max 10 iterations.

## Usage

- `/my-autoresearch my-prompt` — improve /my-prompt with default test inputs
- `/my-autoresearch my-prompt --inputs "Build a REST API" "Fix the auth bug" "Add caching to the DB layer"` — custom test inputs
- `/my-autoresearch my-prompt --checklist "Starts with acceptance criteria?" "Includes what NOT to build?" "Under 50 lines?"` — custom checklist

## Prerequisites

- Target skill must exist at `~/.claude/skills/<name>/SKILL.md`
- Skill must produce text output that can be scored against a checklist

## Behavior

### Step 1 — Gather Inputs (Inversion Pattern)

**DO NOT start the loop until you have all three:**

1. **Target skill name** — from argument or ask
2. **Test inputs** (3-5) — representative prompts that the skill would receive. If not provided, generate 5 diverse test inputs based on the skill's description and purpose.
3. **Binary checklist** (3-6 items) — yes/no questions about the output. If not provided, generate from the skill's rules/gotchas:
   - Read the skill's SKILL.md
   - Extract the key quality criteria from Rules, Gotchas, and purpose
   - Convert to binary questions (e.g., "Does it include acceptance criteria?" not "How good are the criteria?")

### Step 2 — Baseline Score

For each test input:
1. Simulate running the skill (read SKILL.md, apply its instructions to the test input, generate the output it would produce)
2. Score the output against each checklist item (yes=1, no=0)
3. Calculate pass rate: `(total yes) / (total checks * total inputs) * 100`

Report baseline:
```
Baseline: 60% (9/15 checks passed across 5 inputs)
Failing checks:
  - "Includes what NOT to build?" — fails on 4/5 inputs
  - "Under 50 lines?" — fails on 2/5 inputs
```

### Step 3 — Improvement Loop

For each iteration (max 10):

1. **Analyze** — identify the checklist item with the lowest pass rate
2. **Edit** — make ONE targeted change to the skill's SKILL.md that addresses that specific check. Keep the change minimal and isolated.
3. **Re-score** — run all test inputs again with the modified skill, score against checklist
4. **Decide:**
   - If pass rate improved → **keep** the change
   - If pass rate stayed same or worsened → **revert** the change
5. **Log** — append to changelog:
   ```
   Iteration N: targeted "checklist item" — changed "X" to "Y" — pass rate 60%→72% — KEPT/REVERTED
   ```

**Convergence:** Stop when pass rate >= 95% for 3 consecutive iterations.

### Step 4 — Save Results

1. **Save improved skill** as `~/.claude/skills/<name>/SKILL.improved.md` (original untouched)
2. **Save changelog** as `~/.claude/skills/<name>/autoresearch-changelog.md`:
   ```markdown
   # Autoresearch Changelog — <skill-name>
   **Date:** YYYY-MM-DD
   **Baseline:** X% | **Final:** Y% | **Iterations:** N
   **Checklist:**
   1. <item>
   2. <item>

   ## Iterations
   ### 1. Targeted: "<check>"
   **Change:** <what was modified>
   **Result:** X%→Y% — KEPT/REVERTED

   ### 2. Targeted: "<check>"
   ...
   ```
3. **Report:**
   ```
   Autoresearch Complete — <skill-name>
   ═══════════════════════════════════
   Baseline: X% → Final: Y%
   Iterations: N (converged | max reached)

   Changes kept:
     ✓ <change 1> — +12% improvement
     ✓ <change 2> — +8% improvement

   Changes reverted:
     ✗ <change 3> — no improvement

   Improved skill saved to: ~/.claude/skills/<name>/SKILL.improved.md
   Review and rename to SKILL.md to apply.
   ```

### Step 5 — User Decision

Ask the user:
- **Apply** — rename SKILL.improved.md to SKILL.md (backs up original as SKILL.original.md)
- **Review** — show the diff between original and improved
- **Discard** — delete SKILL.improved.md, keep original

## Gotchas

- Binary checklists only — no subjective 1-10 scales (inconsistent grading)
- Sweet spot is 3-6 checklist items — more causes gaming (skill optimizes for checks, not quality)
- One change per iteration — multiple changes make it impossible to isolate what helped
- The changelog is often more valuable than the improved skill — it captures what works/doesn't for that specific task
- Simulated scoring is approximate — real skill invocations via `claude -p` would be more accurate but much more expensive
- Don't run on skills that are primarily structural (like /my-git-sync) — works best on skills that generate text output

## Rules

- Never modify the original SKILL.md — save improvements separately
- One change per iteration — isolate the variable
- Binary checklist items only — "Does it X?" not "How well does it X?"
- Keep changelog for every iteration, including reverted changes
- Stop at 10 iterations even if not converged — diminishing returns
- The user decides whether to apply — never auto-apply
