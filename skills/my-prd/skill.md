---
name: my-prd
description: Use when starting a new feature or project from a raw idea — asks targeted questions and produces a structured PRD at docs/prd-<slug>.md. Sits upstream of /my-prompt. Also use for "write a PRD", "product requirements", or "what should we build".
argument-hint: "< your raw idea or project name >"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(bash:*)
---

<!-- Pattern: Generator -->

# PRD Generator

**Announce at start:** "I'm using the my-prd skill to turn this idea into a structured PRD document."

## Why This Skill Exists

Ideas enter the pipeline unstructured. `/my-prompt` disciplines a task into a prompt, and `/my-create-acceptance-criteria` gates implementation — but neither helps you figure out WHAT to build. This skill fills that upstream gap: raw idea in, structured PRD out.

**Flow:** raw idea -> `/my-prd` -> `docs/prd-<slug>.md` -> `/my-prompt` -> `/my-create-acceptance-criteria` -> implement

---

## Step 0: Resolve Project Root

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
```

Check if `docs/prd-*.md` files already exist. If one matches the current idea, read it and ask the user whether to update it or create a new one.

## Step 1: Gather Existing Context

Read whatever project context exists (skip what doesn't):
- `$PROJECT_ROOT/CLAUDE.md`
- `$PROJECT_ROOT/state.md`
- `$PROJECT_ROOT/architecture.md`
- `$PROJECT_ROOT/docs/` directory listing
- `$PROJECT_ROOT/README.md`

If NONE of these exist, warn: "This project has no existing context. The PRD will be based entirely on our conversation — consider adding a README first."

## Step 2: Ask Targeted Questions (One at a Time)

Ask 3-5 questions to understand the idea. One question per message. Multiple choice preferred when options are clear.

Cover these areas (skip any the user already answered in their initial message):
1. **Problem** — What pain exists? Who feels it? What happens if we don't build this?
2. **Users** — Who uses this? What's their workflow today?
3. **Success** — How do we know it worked? What metric moves?
4. **Constraints** — Tech stack limits, timeline, budget, infra constraints?
5. **Non-goals** — What should we explicitly NOT build?

Do NOT ask all 5 if the idea is simple. 3 questions is fine for a focused feature. Use judgment.

## Step 3: Generate PRD

Write `$PROJECT_ROOT/docs/prd-<slug>.md` where `<slug>` is a lowercase-hyphenated name derived from the idea (e.g., `prd-webhook-handler.md`, `prd-auth-system.md`).

Use this structure:

```markdown
# PRD: <Feature Name>

**Date:** YYYY-MM-DD
**Status:** Draft
**Author:** <user> + Claude

## Problem

What pain exists and who feels it. 2-3 sentences max.

## Users

Who uses this and what their current workflow looks like.

## Requirements

### Must Have
1. <requirement>
2. <requirement>

### Nice to Have
1. <requirement>

## Non-Goals

Things we are explicitly NOT building in this scope:
- <exclusion>

## Success Metrics

How we know this worked:
- <metric>

## Technical Constraints

Stack, infra, or performance limits that shape the solution:
- <constraint>

## Open Questions

Unresolved decisions that need answers before or during implementation:
- <question>
```

Keep it concise. A PRD should be 40-80 lines, not a novel.

## Step 4: Print Next Steps

After writing the file, print:

> PRD written to `docs/prd-<slug>.md`.
>
> **Next steps:**
> 1. Run `/my-prompt` to create a disciplined implementation prompt from this PRD
> 2. Run `/my-create-acceptance-criteria` to generate measurable criteria before coding

---

## Gotchas

- Running on a project with zero context produces a generic PRD — warn the user (Step 1 handles this)
- PRDs for multi-system projects are fine — the PRD captures the vision, decomposition happens downstream at `/my-create-acceptance-criteria` (which has the Topic Scope Test gate)
- Do not include architecture decisions or implementation details — those belong in architecture.md and the implementation plan
- If the user already has a detailed plan and just needs acceptance criteria, skip this skill and go straight to `/my-create-acceptance-criteria`

## Quick Help

**What**: Takes a raw idea and produces a structured PRD document.
**Usage**: `/my-prd add a Stripe webhook handler` — pass your raw idea.
**Output**: A `docs/prd-<slug>.md` file with problem, users, requirements, non-goals, success metrics, constraints, and open questions.
**When**: At the start of any new feature or project, before `/my-prompt`. Not needed for bug fixes or small tasks.
**Upstream of**: `/my-prompt` -> `/my-create-acceptance-criteria` -> implementation.
