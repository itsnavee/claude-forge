---
name: my-project-to-brain-sync
description: Use when you want to update the second-brain knowledge base with this project's current state — exports or updates the project summary at second-brain/projects/<name>.md. Run from any project root. Also use for "sync to brain", "update project summary", or "export to second-brain".
argument-hint: "< notes or focus area | (no arg: full sync) >"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(git:*), Bash(gh:*), Agent
---

# /my-project-to-brain-sync

Export or update this project's summary in the second-brain repo.

**Must be run from a project root** (any directory inside a git repo under `~/code/github/` or `~/data/code/github/`).

## How It Works

1. **Pull latest second-brain** — `cd ~/code/github/second-brain && git pull --rebase origin main`
2. Detect project name from current working directory
3. Check if `~/code/github/second-brain/projects/<name>.md` exists
4. If **no** → full initial indexing (create new summary)
5. If **yes** → incremental update (sync recent changes)
6. **Push changes** — after all writes are done, run the `/git-push` skill from `~/code/github/second-brain/` to stage, commit, and push all changes

---

## Step -1: Pull Latest Second-Brain

Before doing anything, pull the latest changes in the second-brain repo to avoid conflicts:

```bash
cd ~/code/github/second-brain && git pull --rebase origin main
```

If this fails (e.g., uncommitted changes), stash them first (`git stash`), pull, then pop (`git stash pop`). If the pull fails due to network issues, warn the user but continue with the sync.

Then `cd` back to the original project directory to continue.

---

## Step 0: Detect Project Context

```
Git root → derive project name:
  ~/code/github/my-project-3/iphone_app/ → "my-project-3"
  ~/code/github/my-project-5/ → "my-project-5"
  ~/data/code/github/my-project-6/ → "my-project-6"

Logic: find git root, walk up to find the directory directly under ~/code/github/ or ~/data/code/github/
```

Run: `git rev-parse --show-toplevel` to get repo root.
Extract project name: the directory name directly under `code/github/`.

Then check: does `~/code/github/second-brain/projects/<name>.md` exist?

- Active projects live in `projects/<name>.md`
- Inactive/archived projects live in `projects/archived/<name>.md`
- Research, articles, and ideas live under `research/`
- Per-project improvement suggestions live in `improvements/<name>.md`

**If the brain repo doesn't exist at all** (`~/code/github/second-brain/` missing or no `projects/` subdir), tell the user to set it up first and stop.

---

## Step 1 — Delegate Analysis to a Subagent

After detecting the project and confirming the second-brain repo is ready, launch a **single subagent** to do all the heavy reading, analysis, and writing.

**Why a subagent:** Path A reads 11 data sources (git logs, source files, session summaries, docs, deps, MEMORY.md, etc.) which would flood the main agent's context. The subagent handles all I/O; the main agent stays lean.

**Task prompt to pass to the subagent:**

```
You are performing a brain-sync for the project: <project-name>
Project repo path: <repo-path>
Second-brain path: ~/code/github/second-brain/
Existing summary: <"exists" | "does not exist">
Last synced: <date from existing file, or "N/A">
User notes: <any arguments passed to /brain-sync>

Follow Path <A|B> from the brain-sync skill instructions below.
Write the output file(s) directly — do not return the summary inline.
After writing, confirm: which file was written, which sections were created/updated, any notable findings.

<paste the full Path A or Path B instructions below, including Quality Checklist and Anti-Patterns>
```

Wait for the subagent to complete. It will write the summary file and any INDEX.md / CLAUDE.md updates directly.

After the subagent confirms completion, proceed to the Final Step (push changes).

---

## Path A: Initial Export (file doesn't exist)

### A1. Gather Raw Data (run ALL in parallel)

| # | What | Command / Action |
|---|------|-----------------|
| 1 | Git history | `git log --oneline --reverse --format="%h %ai %s"` |
| 2 | File creation dates | `git log --reverse --diff-filter=A --name-only --format="COMMIT:%h %ai %s" -- "*.swift" "*.ts" "*.tsx" "*.py" "*.go" "*.rs"` (pick extensions matching the project language) |
| 3 | Current source structure | `ls` all source code subdirectories 2 levels deep |
| 4 | CLAUDE.md | Read from project root, `.claude/CLAUDE.md`, or `CLAUDE.md` |
| 5 | MEMORY.md | Find in `~/.claude/projects/` matching this project path |
| 6 | Dependencies | Read `package.json` / `go.mod` / `Package.swift` / `Podfile` / `requirements.txt` / `Cargo.toml` |
| 7 | Docs folder | List all files in `docs/` with first-line titles |
| 8 | Env files | Check `.env*` / `.env.example` for service names (DO NOT copy key values) |
| 9 | Session summaries | Read files in `.claude/sessions/` |
| 10 | Transcript count | Count `.jsonl` files in `~/.claude/projects/` matching project path |
| 11 | Key source files | Read main entry points (app entry, main route, index.ts/main.go/etc.) to understand what the project actually does |

### A2. Analyze Before Writing

- **Understand what this project does from a user's perspective.** You must be able to explain the core user interaction in one paragraph.
- **Identify key architectural decisions and rationale.** Why each major technology? Check MEMORY.md, docs, CLAUDE.md for clues.
- **Map project journey from git history.** Group commits into phases by time gaps + theme. Note batch pushes honestly.
- **Identify what's incomplete or broken.** TODOs, stubs, deprecated-but-not-removed code, "in progress" markers.

### A3. Verify Claims Against Reality

Before writing, spot-check:
- If docs say something was "removed"/"archived" → verify files actually gone
- If docs say a service exists → verify file exists with real content (not stub)
- If MEMORY.md says a pattern is used → verify in code
- Note discrepancies in "What's Incomplete"

### A4. Write the Summary

Create `~/code/github/second-brain/projects/<name>.md` with these sections IN ORDER (or `projects/archived/<name>.md` if the project is inactive). All required unless marked optional.

```
# <Project Name>

## Overview
What it is, who it's for, HOW the core interaction works. One paragraph.

## Status
Active/maintained/archived. Current focus. Link to What's Incomplete.

## Core User Flow
ASCII pipeline showing the primary user interaction.
Show data flow — what triggers what, what calls what.

## Technology & Services Inventory
| Category | Technology | Why this choice |
"Why this choice" = rationale. If unknown, say "rationale unknown".

## Architecture & Modules
Organized by SUBSYSTEM (not flat list). Show how subsystems connect.
Note file sizes for oversized files.

## Key Decisions
| Decision | Chosen | Over | Why |
Only where alternatives existed. 5-10 rows max.

## Project Journey
Phases from git history. Rules:
- Note pre-git work if first commit is a big dump
- Note batch pushes ("accumulated work pushed in one commit")
- Skip trivial commits
- Include WHY for major changes

## What's Incomplete
Most actionable section:
- Blocking items (prevents shipping/using)
- Known bugs / tech debt
- Planned but unstarted (link to docs)
- Security concerns

## Ideas → Plans → Implementation Trail
| Idea/Doc | What it became | Status |
Bold **In progress** and **Not started** items.

## Problems & Fixes
| Problem | Resolution | Source |
Include UNRESOLVED problems too.

## Cross-Project Relevance
| Pattern | Shared With | Notes |
Only genuinely transferable patterns. No speculation.

## Key Docs
| When you need... | Read |
Lookup by use case. 5-10 rows.

## Links
Repo path, CLAUDE.md, MEMORY.md, transcript count.

## Last Synced
<today's date>
```

### A5. Update INDEX.md

In `~/code/github/second-brain/INDEX.md`:
- Add to Active Projects table (or Inactive/Archive table, linking to `projects/archived/<name>.md`)
- Add column to Technology Matrix
- Add to Cross-Project Patterns if applicable
- Add to Data Sources

### A6. Update CLAUDE.md

In `~/code/github/second-brain/.claude/CLAUDE.md`:
- Add project name to Active Projects list

### A7. Update OWNER-CONTEXT.md

In `~/code/github/second-brain/OWNER-CONTEXT.md`:
- Add or update the project's row in the projects table (name, stack, phase, top gaps)
- This file is injected into research subagents — keeping it current ensures new research is classified against current project state

---

## Path B: Incremental Update (file exists)

### B1. Find What Changed

Read existing `projects/<name>.md` → extract `Last Synced` date.

Run in parallel:
| # | What | Command |
|---|------|---------|
| 1 | New commits | `git log --oneline --since="<last-synced>"` |
| 2 | Changed files | `git diff --stat HEAD~N` (N = new commit count) |
| 3 | New transcripts | Find `.jsonl` files in `~/.claude/projects/` modified after last sync |
| 4 | Dependency changes | `git diff <last-synced-commit>..HEAD -- package.json go.mod Package.swift requirements.txt` |
| 5 | New session summaries | Check `.claude/sessions/` for new files |
| 6 | MEMORY.md changes | Compare current MEMORY.md modification date vs last sync |

### B2. Decide What to Update

Only touch sections with new data:
- **Project Journey**: New phase if meaningful commits exist
- **Architecture**: If new services/managers/modules added
- **Tech Inventory**: If new dependencies appeared
- **Problems & Fixes**: From new session summaries or MEMORY.md changes
- **What's Incomplete**: Re-verify — things marked "in progress" may be done now, new blockers may exist
- **Status**: If project focus changed
- **Cross-Project Relevance**: If new patterns emerged

### B3. Verify What's Incomplete

This is the most important step in an update. For every item currently in "What's Incomplete":
- Check if it's been resolved (files added, code changed, etc.)
- Mark resolved items and remove them
- Add any new incomplete items discovered

### B4. Update Metadata

- Update `Last Synced` to today
- Update INDEX.md if status or tech matrix changed
- Update transcript count in Links section
- Update OWNER-CONTEXT.md if project phase, stack, or top gaps changed

### B5. Don't Over-Update

- Don't rewrite the entire summary
- Don't add phases for trivial commits ("occasional commit", typo fixes)
- Don't modify the project's own repo — only write to `~/code/github/second-brain/`
- Don't read full JSONL transcripts (too large) — use session summaries + MEMORY.md

---

## Quality Checklist (verify before saving)

- [ ] Can someone new understand what this project does from Overview + Core User Flow?
- [ ] Tech inventory has rationale, not just names?
- [ ] Architecture shows data flow between subsystems, not a flat component list?
- [ ] Key Decisions captures WHY, with alternatives considered?
- [ ] Project Journey is honest about batch pushes and pre-git work?
- [ ] What's Incomplete lists actual blockers verified against codebase?
- [ ] Cross-Project Relevance only lists genuinely transferable patterns?
- [ ] No filler (doc count tables, vague session counts, flat file timelines with same date)?
- [ ] All claims verified against actual code?

## Anti-Patterns

- **No doc count tables** ("Other: 34") — use lookup table by use case
- **No File-Level Timeline** where every "Last Major Change" is the same date
- **No vague Prompt History** ("49 sessions") — summarize key decisions or skip
- **No speculative cross-project reuse** — only patterns you'd actually copy
- **No "archived" if files still in active directory** — verify first
- **No padding** tech inventory with "N/A" rows

---

## Output

After completing, briefly report:
- Whether this was a new export or update
- Sections created/updated
- Any notable findings (new blockers, resolved items, discrepancies)

---

## Final Step: Push Changes

After all writes to the second-brain repo are complete, `cd` to `~/code/github/second-brain/` and invoke `/my-git-sync` to stage, commit, and push all changes. The commit message should reference the project that was synced (e.g., "brain-sync: update my-project-3 summary").

## Gotchas

- Must be run from the project root, not from second-brain — it reads the current project's files
- Overwrites the existing project summary — make sure the latest version is committed first

## Quick Help

**What**: Exports current project's codebase into a structured summary at `~/code/github/second-brain/projects/<name>.md`.
**Direction**: Project repo → second-brain (one-way). Never writes back to the project.
**Usage**:
- `/my-project-to-brain-sync` — run from any project root
- `/my-project-to-brain-sync focus on API changes` — with optional notes
**Modes**: New project (Path A — full initial export) or existing (Path B — incremental update since last sync).
**Also updates**: INDEX.md, CLAUDE.md, OWNER-CONTEXT.md in second-brain repo.
