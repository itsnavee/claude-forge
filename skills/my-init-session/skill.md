---
name: my-init-session
description: Use when starting an implementation session on any project — creates or updates features.json, runs init checks, verifies environment, and sets up clean state for the worker session. Also use for "init session", "set up for implementation", or "prepare to code".
argument-hint: "< phase name | feature | (no arg: auto-detect) >"
---

<!-- Pattern: Inversion + Pipeline -->

# /my-init-session — Session Initializer

Prepares a clean working environment before implementation begins. Creates structured task tracking (features.json), verifies the environment, and ensures the session starts from a known-good state. This is the "initializer agent" from the two-agent architecture pattern.

**DO NOT start any implementation work. This skill only sets up the environment.**

## Usage

- `/my-init-session` — auto-detect project, create/update features.json
- `/my-init-session my-project-2` — init for a specific project
- Run at the start of any implementation session

## Behavior

### Step 1 — Detect Project

1. Read `state.md` — current phase, active tasks, resume point
2. Read `architecture.md` — project structure, key modules
3. Read `CLAUDE.md` — project rules and conventions
4. If `docs/acceptance-criteria.md` exists, read it for feature list

### Step 2 — Create or Update features.json

Generate/update `features.json` in the project root:

```json
[
  {
    "name": "Feature name from state.md or acceptance criteria",
    "steps": [
      "Step 1 description",
      "Step 2 description",
      "Step 3 description"
    ],
    "passes": false,
    "started": false
  }
]
```

**If features.json exists:** Read it, update steps for incomplete features, add any new features from state.md, mark completed features as `"passes": true`.

**If features.json doesn't exist:** Generate from state.md Active/Queued section + acceptance criteria.

### Step 3 — Environment Checks

Run in parallel:
```bash
# Git status — must be clean
git status --short

# Dependencies installed
[ -f "package.json" ] && npm ls --depth=0 2>/dev/null | tail -1
[ -f "requirements.txt" ] && pip check 2>/dev/null | head -5
[ -f "go.mod" ] && go mod verify 2>/dev/null | tail -1

# Docker services (if applicable)
docker compose ps --format "table {{.Name}}\t{{.Status}}" 2>/dev/null

# Tests pass
# (detect test runner and run)
```

### Step 4 — Set Resume Point

Update `state.md`:
- Set **Last activity** to today + "session initialized"
- Set **Resume Point** to the first incomplete feature from features.json

### Step 5 — Report

```
Session Initialized — <project-name>
═══════════════════════════════════════
Phase: <current phase from state.md>
Features: N total (M complete, K remaining)

Next feature: <first incomplete feature name>
  Steps: <step list>

Environment:
  ✓ Git: clean
  ✓ Dependencies: installed
  ✓ Docker: 3/3 services running
  ✗ Tests: 2 failing (test_auth.py, test_webhook.py)

Ready to implement. Work one feature at a time.
Each completed feature: git commit + update features.json.
```

## Gotchas

- Don't run this on the second-brain repo — it's not an implementation project
- features.json should have 3-8 features max — if more, the scope is too large for one session
- Environment checks may fail on first run (missing deps, Docker not started) — report and let user fix
- state.md must exist — if it doesn't, suggest running /my-save first to create it

## Rules

- **Zero implementation work** — only environment setup and task tracking
- features.json is the source of truth for task tracking — state.md reflects it
- Each feature should be completable in one focused session (< 200 lines of change)
- If features.json has >8 incomplete features, warn: "Scope too large for one session — pick 3-5 to focus on"
- Always end with a clear "next feature" recommendation
- Git must be clean before starting — if dirty, warn and ask to commit or stash first
