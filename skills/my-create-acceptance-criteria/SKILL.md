---
name: my-create-acceptance-criteria
description: Use when starting implementation on any project — reads planning docs, dispatches sub-agents, and creates or reiterates docs/acceptance-criteria.md with measurable criteria per feature. Must run before writing implementation code. Also use for "create acceptance criteria", "what are the requirements", or "define done".
argument-hint: "< phase or feature to focus on | (no arg: all) >"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Agent
---

# Create Acceptance Criteria

**Announce at start:** "I'm using the my-create-acceptance-criteria skill to analyze all project docs and produce an acceptance criteria document."

## Why This Skill Exists

No project is built without acceptance criteria. LLMs generate what was described, not what was needed — and without measurable criteria defined upfront, there is no way to know whether the implementation is correct vs plausible-looking. This skill enforces that gate.

**Rule:** If `docs/acceptance-criteria.md` does not exist in the project, this skill must be run before any phase implementation begins. If it exists, this skill must be run to reiterate it whenever a new phase doc or planning doc is added.

---

## IMPORTANT: DO NOT proceed to generating criteria until you have:

1. Read all planning docs in `docs/` (build/, planning/, any root .md files)
2. Read `CLAUDE.md` and existing acceptance criteria (if any)
3. Confirmed with the user what phase/scope to cover

This is a hard gate. Skipping context gathering produces generic, useless criteria.

---

## Step 0: Resolve Project Root

Before any file operations, resolve the git repo root. All project-relative paths (`docs/`, `state.md`, `.claude/`) are relative to this root, NOT `pwd`.

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
```

## Step 1: Discover all project docs

Scan the project for all planning and build documentation:

```
docs/build/          — phase docs, implementation plans, tracking
docs/planning/       — architecture decisions, schema, tech stack, key decisions
docs/               — any other .md files at root
```

List every file found. Note which exist and which are missing from the expected set.

Expected files (for a typical project):
- `docs/build/phase-N.md` for each phase
- `docs/planning/db-schema.md` or equivalent
- `docs/planning/tech-stack.md` or equivalent
- `docs/planning/key-decisions.md` or equivalent
- `docs/build/execution-tracking.md`

---

## Step 2: Dispatch parallel reading agents

Dispatch THREE agents in parallel to deeply read different doc sets.

Read `references/agent-prompts.md` for the full agent dispatch prompts.

Summary of agents:
- **Agent 1 — Phase Docs Reader**: Reads all `docs/build/phase-*.md`, extracts what ships, success criteria, dependencies, deferred items.
- **Agent 2 — Planning Docs Reader**: Reads all `docs/planning/`, extracts data model, tech stack, security model, performance targets.
- **Agent 3 — Gap Analyst (Skeptic)**: Loads `~/.claude/agents/debate/skeptic.md` identity, finds every gap in the above summaries. Returns gaps by severity.

---

## Step 3: Check for existing acceptance criteria

Check if `docs/acceptance-criteria.md` exists.

**If it does NOT exist:** proceed to Step 4 to create it from scratch.

**If it DOES exist:** read it. Note what is already covered. Step 4 will reiterate — expanding, correcting, and sharpening what exists rather than replacing it wholesale. Every existing criterion must be evaluated: is it still accurate? Is it measurable? Is it verifiable?

---

## Step 4: Produce the acceptance criteria document

Write (or rewrite) `docs/acceptance-criteria.md`.

Read `references/validation-checklist.md` for the full document structure template and criterion quality rules.

The runtime rules template to embed in the document is in `references/agent-prompts.md`.

---

## Step 5: Validate the document

Read `references/validation-checklist.md` for the full validation checklist.

If any check fails, fix the document before finishing.

---

## Step 6: Print summary

Output:
1. Whether this was a create or reiterate operation
2. How many criteria were added or changed
3. The top 5 critical gaps found by the Skeptic agent
4. File path of the written document

---

## Gotchas

- Running on a project with no `docs/` directory produces generic criteria — needs at least a README or planning doc
- Sub-agents may generate criteria that overlap or contradict — manual dedup pass is needed after generation
- "It works" is not an acceptance criterion — every item must have a verifiable assertion

## Notes

- This skill uses your project's `docs/build/acceptance-criteria.md` as the gold standard template. When creating criteria for a new project, model the depth and specificity of that document.
- The Skeptic agent (`~/.claude/agents/debate/skeptic.md`) is the most important sub-agent here. Load its identity before the gap analysis phase.
- This skill should be re-run whenever: a new phase doc is added, a major architectural decision changes, or an implementation phase reveals gaps not previously considered.
- Never mark a project as "ready to implement" until this doc exists and passes the Step 5 self-check.

## Quick Help

**What**: Creates or reiterates `docs/acceptance-criteria.md` with measurable, verifiable criteria extracted from planning docs.
**Usage**:
- `/my-create-acceptance-criteria` — full project scan
- `/my-create-acceptance-criteria phase-4` — focus on a specific phase
**Gate**: Global CLAUDE.md requires this file before any implementation starts.
**Agents used**: Phase Docs Reader, Planning Docs Reader, Gap Analyst (Skeptic personality).
**References**: `references/agent-prompts.md`, `references/validation-checklist.md`
