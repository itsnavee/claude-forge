---
name: my-loop
description: Use when you have multiple tasks to execute sequentially — generates disciplined prompts via /my-prompt, then executes each task with plan→criteria→build→review→docs→checkpoint cycle. Also use for "run these tasks", "execute the list", or "loop through tasks".
argument-hint: "< task list | dry-run | (no arg: use existing list) >"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Agent, Skill
---

# Task Loop — Plan, Build, Review, Ship

**Announce at start:** "Using /my-loop to execute the task queue with structured checkpoints."

## Quick Help

**What**: Takes tasks from conversation context, generates a disciplined execution prompt, then runs each task through a strict cycle: plan → acceptance criteria → implement → /simplify → update docs → /my-save-&-git-sync.
**Usage**:
- `/my-loop` — picks up tasks from current conversation context
- `/my-loop dry-run` — generates the execution prompt but does NOT execute (preview mode)
**Safety**: Skips tasks needing critical human decisions (flags in todo). Punts human-dependent blockers to manual-tasks file. Updates all tracking docs before each checkpoint.

---

## Step 0: Resolve Project Root

Before any file operations, resolve the git repo root. All project-relative paths (`state.md`, `architecture.md`, `docs/`, `.claude/sessions/`) are relative to this root, NOT `pwd`.

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
echo "PROJECT_ROOT=$PROJECT_ROOT"
```

## Step 0a: Gather Tasks

Collect the task list from the current conversation. Tasks should already be discussed and agreed upon with the user.

If no tasks are evident in conversation context, ask the user: "What tasks should I execute? List them in priority order."

If argument is `dry-run`, execute only Steps 1-2 (prompt generation), then output the prompt and STOP.

---

## Step 1: Initial Checkpoint

Run `/my-save-&-git-sync` to create a clean starting point before any work begins.

---

## Step 2: Generate Execution Prompt

Run `/my-prompt` on the full task list with the following context injected:

```
Task queue: [list all tasks with numbers]

Generate a disciplined execution prompt for these tasks. Include per-task:
- Scope constraints (max lines, max files, max dependencies)
- What NOT to build (explicit exclusions)
- Files to check in codebase before writing new code
- Verification method

Also include these execution rules:
- Tasks requiring critical human decisions: SKIP, mark as "needs-decision" in todo
- Tasks blocked by external dependencies: document blocker, punt to manual-tasks, move to next
- Line budget exceeded by >50%: stop, split into sub-tasks, checkpoint what's done
```

Review the /my-prompt output. If any task-specific constraint is missing or vague, add it before proceeding.

---

## Step 3: Read Context Files + Locate Tracking Files

### 3a: Read state.md and architecture.md

Before starting any work, read these files if they exist in the project root:

- **`state.md`** — current phase, completed work, active tasks, blockers, resume point. This tells you what's done and what to skip.
- **`architecture.md`** — directory map, services, modules, data flow. This tells you where files live without scanning.
- **`CLAUDE.md`** — project rules, coding conventions, constraints. This tells you HOW to work.

If `state.md` or `architecture.md` don't exist, create them before starting (see global CLAUDE.md for format).

### 3b: Locate Tracking Files

Find the project's tracking files. Search in this order:

**Todo files:**
```
docs/todo/now.md
docs/todo/done.md
```

**Manual tasks file (human-dependent items):**
```
docs/todo/manual-tasks.md
docs/implementation/manual-tasks.md
docs/manual-tasks.md
```

**Implementation progress files:**
```
docs/implementation/*/progress.md
docs/implementation-phases/*.md
```

Use Glob to find whichever exist. Store the paths — you will update these after each task.

If no manual-tasks file is found, note this and create one at `docs/todo/manual-tasks.md` if a blocker arises.

---

## Step 4: Execute Task Loop

For each task in the queue, in order:

### Phase A: Codebase Reality Check (before anything else)

Docs may be outdated. The codebase may already have this task fully or partially implemented. Before planning or triaging:

1. **Search the codebase** for existing implementations — use Grep/Glob for relevant components, API endpoints, routes, and files
2. **If fully implemented** → mark as done in todo, skip to next task. Do NOT re-implement.
3. **If partially implemented** → note what exists, plan only covers the gaps
4. **If not implemented** → proceed to Triage

### Phase B: Triage

Ask yourself:
1. **Does this task need a critical decision I can't make?** (auth strategy, pricing model, vendor choice, UX flow that user hasn't specified)
   - YES → Mark as `needs-decision` in todo file with a note on WHAT decision is needed. Skip to next task.
2. **Is this task blocked by something a human must do?** (API credentials, account setup, DNS config, legal review)
   - YES → Append to manual-tasks file with context. Skip to next task.
3. **Is this task trivial?** (< 30 lines, no design decisions, single file edit)
   - YES → Skip the plan file. Note "trivial — no plan needed" and go straight to Phase D.

### Phase C: Plan

1. Write plan to `docs/implementation-phases/YYYY-MM-DD-<task-slug>.md`
2. Plan must include:
   - Files to create/modify (check codebase first — prefer editing existing files)
   - What NOT to build (explicit scope limits from the /my-prompt output)
   - Estimated line count budget
3. Run `/my-create-acceptance-criteria` focused on this task's plan
   - Criteria go at the TOP of the plan file
   - If any criterion is unmeasurable, rewrite it
4. Dispatch architect sub-agent to review the plan — fix issues before proceeding

### Phase D: Implement

1. Write the code following existing codebase patterns
2. Stay within line budget. If exceeding by >30%, stop and split
3. Prefer editing existing files over creating new ones
4. Do NOT add dependencies without stating why

### Phase E: Review

1. Run `/simplify` on all changed files
2. Fix every valid finding
3. Do NOT run additional review sub-agents — /simplify already runs 3 (reuse, quality, efficiency)

### Phase F: Build, Test & Verify

After code changes, verify everything works end-to-end:

1. **Rebuild affected containers** — `docker compose -f infra/docker-compose.stg.yml build --no-cache <service>` for each app that changed
2. **Restart containers** — `docker compose -f infra/docker-compose.stg.yml up -d <service>`
3. **Run backend tests** — `docker compose exec -e AUTH_DISABLED=true backend python -m pytest tests/ -v --tb=short`
4. **Run frontend tests** — `docker compose exec studio npx vitest run` / `docker compose exec website npx vitest run`
5. **Check container logs** — `docker compose logs --tail=10 <service>` — look for errors, crashes, import failures
6. **Fix any failures** — if tests fail or containers crash, fix the root cause (missing migrations, wrong column names, route conflicts, etc.) before proceeding
7. **Verify all containers are running** — `docker compose ps` — all should show "Up", none "Restarting"

Skip this phase only for trivial doc-only changes.

### Phase G: Update Docs

Before checkpointing, update ALL tracking files:

1. **state.md** — update "Recently Completed", "Active / Queued", "Resume Point". Keep under 60 lines. Only update every 3-5 tasks to avoid noise.
2. **Todo now.md** — mark task as done or update status
3. **Todo done.md** — move completed task entry with date and notes
4. **Implementation progress files** — update the relevant `progress.md` for the app/service touched
5. **Plan file** — check off completed steps if using checkbox format

### Phase H: Checkpoint

Run `/my-save-&-git-sync` with context about what was completed.

### Phase I: Context Check

Before moving to the next task, check if context exceeds 200K tokens. If it does:
1. Run `/my-save` (state is already saved from Phase H, but this ensures state.md is current)
2. Compact context — let the system summarize and compress
3. After compaction, re-read `state.md`, `architecture.md`, and the `/my-prompt` output from Step 2 to restore working context

If context is under 200K, move directly to the next task.

---

## Step 5: Loop Summary

After all tasks are processed (completed, skipped, or punted), output a summary:

```
## Loop Complete

### Completed
- [task] — [commit hash]

### Skipped (needs-decision)
- [task] — [what decision is needed]

### Punted (manual-tasks)
- [task] — [what blocker needs human action]

### Failed
- [task] — [why it failed, what was salvaged]
```

---

## Gotchas

- Context is checked after each task (Phase I) — compaction triggers automatically at 200K tokens
- For very long task lists (10+), expect compaction every 2-3 tasks
- /my-prompt runs once at the start (Step 2) for all tasks — do NOT call it again per-task during the loop

## Rules

- Never execute without running /my-save-&-git-sync first (Step 1)
- Never skip doc updates (Phase E) — this is how the user knows what happened when they return
- Tasks needing human decisions are SKIPPED, not attempted with assumptions
- Manual blockers go to the manual-tasks file, not inline comments in code
- If /simplify finds architectural issues (not just style), fix before checkpoint
- Do NOT create documentation beyond plan files — no READMEs, no ADRs, no changelogs
- The /my-prompt output is the source of truth for task constraints — follow it
- Compaction threshold is 200K tokens — Phase I handles this automatically after each task checkpoint
