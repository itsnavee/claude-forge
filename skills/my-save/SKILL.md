---
name: my-save
description: Use when ending a session or at a natural checkpoint — saves session summary, updates state.md, copies transcript, extracts learnings, and triggers consolidation when 5+ sessions accumulate. Also use for "save", "save session", or "checkpoint".
argument-hint: "< notes about session | (no arg: auto-summarize) >"
---

# Save Session Summary

Save a summary of the current session to `.claude/sessions/summary_YYYY-MM-DD.md` using today's date.

**All project-relative paths below are relative to `PROJECT_ROOT`, not `pwd`.**

## Step 0a: Resolve Project Root

Run this first — all file paths in this skill are relative to this root:

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
echo "PROJECT_ROOT=$PROJECT_ROOT"
```

Use `$PROJECT_ROOT/.claude/sessions/`, `$PROJECT_ROOT/state.md`, `$PROJECT_ROOT/architecture.md`, etc. throughout. Never assume `pwd` is the project root.

## Step 0b: Detect Agent Runtime

Run this bash command first to detect which agent you're running in:

```bash
if [ -n "$CLAUDE_SESSION_ID" ]; then
  echo "AGENT=claude"
  echo "SESSION_ID=${CLAUDE_SESSION_ID:0:8}"
elif [ -d "$HOME/.pi/agent" ] && pgrep -f "pi-coding-agent" >/dev/null 2>&1; then
  echo "AGENT=pi"
  echo "SESSION_ID=$(date +%s | shasum | head -c 8)"
elif [ -n "$PI_CODING_AGENT_DIR" ]; then
  echo "AGENT=pi"
  echo "SESSION_ID=$(date +%s | shasum | head -c 8)"
else
  # Fallback: check parent process name
  PARENT=$(ps -o comm= -p $PPID 2>/dev/null || echo "")
  if echo "$PARENT" | grep -qi "pi"; then
    echo "AGENT=pi"
  else
    echo "AGENT=claude"
  fi
  echo "SESSION_ID=$(date +%s | shasum | head -c 8)"
fi
```

Detection priority:
1. `CLAUDE_SESSION_ID` env var → Claude Code
2. `~/.pi/agent` exists + pi process running → Pi
3. `PI_CODING_AGENT_DIR` env var → Pi
4. Parent process name check → fallback

This sets two values you'll use throughout:
- **AGENT** — `claude` or `pi`
- **SESSION_ID** — 8-char identifier (Claude uses its session ID, Pi generates one from timestamp)

## Rules

1. **Check if file exists** — look for today's summary file at `$PROJECT_ROOT/.claude/sessions/summary_YYYY-MM-DD.md`
2. **If exists** — append after the last line, starting with `\n---\n`
3. **If not** — create the file
4. **Session ID** — use the SESSION_ID from Step 0
5. **Be concise** — follow the format below strictly, no filler text

> **Both agents save to `.claude/sessions/`** — this is intentional. Session history is shared so either agent can load context from the other's work.

## Format

```markdown
## Session: <8-char session id> (via <claude|pi>)
**Topics:** tag1, tag2, tag3
**Entities:** LibraryName, ServiceName, APIName
**Importance:** 0.3 | 0.5 | 0.7 | 1.0
**Consolidated:** no

# Session Summary — YYYY-MM-DD

## Task: <brief title>

<1-2 sentence overview of what was done>

## Changes Made

### <change category>
**File**: `path/to/file`
- **Problem**: what was wrong
- **Fix**: what was done

## Commits
- `<hash>` — commit message

## Status
Complete/Incomplete. Any follow-up notes.
```

### Metadata Rules

- **Topics**: 2-4 lowercase keyword tags describing what was worked on (e.g., `auth, middleware, redis`)
- **Entities**: proper nouns — libraries, services, APIs, tools touched this session (e.g., `Clerk, NextAuth, Redis`)
- **Importance**: self-rate based on scope of work:
  - `0.3` — trivial (typo fix, variable rename, small config change)
  - `0.5` — routine (bug fix, minor feature, dependency update)
  - `0.7` — significant (new feature, architectural change, complex debugging)
  - `1.0` — critical (new architecture, production fix, major decision)
- **Consolidated**: always starts as `no`; flipped to `yes` by consolidation step

## Copy Transcripts

After writing the summary, sync all missing transcripts from `~/.claude/projects/` to the project.

**Skip list** — do NOT copy transcripts for these projects (no value, or config-only repos):
`claude-forge`, `claude-config`

6. **Copy transcripts** — derive the source directory and sync all missing jsonl files:

   ```bash
   # Derive source dir from PROJECT_ROOT
   PROJECT_KEY=$(echo "$PROJECT_ROOT" | sed 's|/|-|g; s|^-||')
   SOURCE_DIR="$HOME/.claude/projects/-${PROJECT_KEY}"
   DEST_DIR="$PROJECT_ROOT/.claude/transcripts"

   # Skip list check
   PROJ_NAME=$(basename "$PROJECT_ROOT")
   case "$PROJ_NAME" in claude-forge|claude-config) echo "SKIP: $PROJ_NAME is on transcript skip list"; exit 0;; esac

   # Sync all missing transcripts
   mkdir -p "$DEST_DIR"
   COPIED=0
   for src in $(find "$SOURCE_DIR" -name "*.jsonl" -type f 2>/dev/null); do
     fname=$(basename "$src")
     [ -f "$DEST_DIR/$fname" ] && continue
     cp "$src" "$DEST_DIR/$fname" && COPIED=$((COPIED + 1))
   done
   echo "Copied $COPIED new transcripts to $DEST_DIR"
   ```

   - **Pi**: `mkdir -p "$PROJECT_ROOT/.claude/transcripts" && cp $(ls -t ~/.pi/agent/sessions/**/*.jsonl 2>/dev/null | head -1) "$PROJECT_ROOT/.claude/transcripts/" 2>/dev/null`
   - Silently skip if source directory doesn't exist or project is on skip list.

---

## Update state.md + architecture.md

After writing the summary and copying the transcript, ensure state.md and architecture.md exist and are up to date.

7. **Check for state.md and architecture.md** at `$PROJECT_ROOT/` (the git repo root, NOT `pwd`).

8. **If state.md does NOT exist** — create it by analyzing the project:
   - Read git log (last 10 commits), directory structure, any existing docs/todo/planning files, and CLAUDE.md
   - Generate state.md with these sections (~40-60 lines):
     ```
     # State
     ## Current Position — phase, last activity date, status
     ## Recently Completed — last ~8 completed items
     ## Active / Queued — current and upcoming tasks
     ## Active Decisions — key architectural decisions in effect
     ## Blockers — anything blocking progress
     ## Resume Point — what to do next
     ```

9. **If architecture.md does NOT exist** — create it by analyzing the project:
   - Read directory tree (top 2-3 levels), package files, config files, existing docs
   - Generate architecture.md with these sections (~60-100 lines):
     ```
     # Architecture
     ## Services — table of services with path, framework, port, URL
     ## Project Layout — directory tree (top 2-3 levels)
     ## Key Modules — table of modules with purpose
     ## Data Flow — ASCII diagram of how data moves through the system
     ## Key Config Files — table of important config files
     ## Imports Convention — how imports work in this project
     ```

10. **If state.md exists** — update these sections based on the session summary you just wrote:

    - **Last activity** — set to today's date + a brief description of what was done this session
    - **Resume Point** — update to reflect what should be done next (based on remaining work, blockers, or the next logical step)
    - **Recently Completed** — move any tasks that were completed this session from Active/Queued to Recently Completed (add to top of list, keep last ~8 items)
    - **Active / Queued** — remove completed tasks, add any new tasks discovered during the session
    - **Blockers** — update if blockers were resolved or new ones discovered
    - **Current Position status** — update the status line if phase/sprint state changed

   **Rules:**
   - Only update fields that changed this session — don't rewrite the whole file
   - Keep the same format and section structure — use Edit tool, not Write
   - If a section doesn't need updating, leave it alone
   - state.md must stay under 60 lines, architecture.md under 100 lines
   - architecture.md only needs updating if services/modules were added or removed this session

---

## Learning Extraction

After saving the summary and updating state.md, extract learnings from this session into `~/.claude/learning/`. This populates the statusline learning graph automatically.

11. **Classify the session** — review what happened and determine which categories apply. A session can produce entries in multiple categories, one, or none. Don't force entries — only write when there's a genuine learning.

12. **Write entries** — append to the appropriate file(s) in `~/.claude/learning/`. Each entry MUST start with `### ` (the statusline counts these).

**Format:**
```markdown
### YYYY-MM-DD — short title
**Project**: project-name
**Context**: 1-2 sentences of what happened
**Learning**: the actual takeaway — what to do differently next time
```

**Category rules:**

| File | Write when... | Example |
|------|--------------|---------|
| `failures.md` | You hit a bug that took real debugging effort, something broke unexpectedly, or a fix that seemed right turned out wrong | "macOS `date %P` returns bare letter, not am/pm — use `%p` + lowercase" |
| `system.md` | Infra/tooling/env issue — hook failure, config problem, deployment error, CLI quirk | "statusline edits to repo copy don't take effect — must also sync to ~/.claude/" |
| `algorithm.md` | Wrong approach taken, over-engineered solution, missed a simpler path, requirements misunderstood | "built custom parser when jq one-liner would suffice" |
| `signals.md` | Every session gets a rating entry (mandatory) | See format below |
| `synthesis.md` | Skip — populated by consolidation step only |

13. **Rate the session** (mandatory) — append to `~/.claude/learning/signals.md`:

```markdown
### YYYY-MM-DD — session-id — rating/10
**Project**: project-name | **Task**: brief task title
**Rating reason**: 1 sentence why this rating
```

Rating guide: 1-3 = frustrating/broken, 4-5 = rough but got there, 6-7 = solid session, 8-9 = very productive, 10 = exceptional

**Rules:**
- Only write genuine learnings — not every session produces failures/system/algorithm entries
- Don't duplicate — check if a similar entry already exists before appending
- Keep entries concise — 3-5 lines max per entry
- signals.md rating is the only mandatory entry every session

---

## Consolidation Step

After steps 1-10, check if consolidation should run. This turns `/my-save` from write-only into write-and-consolidate.

11. **Count unconsolidated sessions** — search for `**Consolidated:** no` across all `.claude/sessions/summary_*.md` files. Count matches.
12. **Gate check** — if fewer than 5 unconsolidated sessions exist, STOP here. Consolidation is not needed yet.

If >= 5 unconsolidated sessions:

13. **Read recent summaries** — Read the summary files containing unconsolidated sessions (up to the 10 most recent)
14. **Read current MEMORY.md** — Find the project's memory file:
    - **Claude**: `~/.claude/projects/<project-path>/memory/MEMORY.md`
    - **Pi**: Check `.claude/memory/MEMORY.md` in the project root first, then fall back to `~/.claude/projects/<project-path>/memory/MEMORY.md` (shared with Claude)
15. **Consolidate** — Analyze the unconsolidated sessions and identify:
    - **Recurring patterns or mistakes** across sessions (same bug class, same debugging approach)
    - **New architectural decisions** that should be permanent knowledge
    - **Gotchas** that came up multiple times
    - **Cross-project connections** — did this session touch a pattern that exists in another project? (check second-brain `projects/` if unsure)
16. **Update MEMORY.md** — Append consolidated insights under a new section:

```markdown
## Consolidated — YYYY-MM-DD

### Patterns
- <pattern discovered across sessions>

### Decisions
- <architectural decision worth remembering permanently>

### Gotchas
- <recurring issue or mistake>

### Cross-Project Connections
- project-a/area ↔ project-b/area — <relationship description>
```

Only include subsections that have actual content. Skip empty ones.

15. **Importance-based compression** — For each consolidated session:
    - If importance was `0.3`: compress the session entry to a single line: `## Session: <id> — <task title> (trivial, consolidated YYYY-MM-DD)`
    - If importance was `0.5`: keep task title + 1-line summary, remove Changes Made details
    - If importance was `0.7` or `1.0`: keep full detail
16. **Mark consolidated** — Edit each processed session entry: change `**Consolidated:** no` to `**Consolidated:** yes`

### Consolidation Rules

- Never delete session entries — only compress low-importance ones
- Never duplicate what's already in MEMORY.md — check before appending
- Cross-project connections should be specific (name both projects and the shared pattern), not vague
- If MEMORY.md doesn't exist yet, create it with the consolidated section
- Keep MEMORY.md under 200 lines — if approaching the limit, merge older consolidated sections into tighter summaries

## Arguments

If the user passes arguments with `/save` or `/skill:my-save`, incorporate them as context for what to emphasize in the summary.

## Quick Help

**What**: Saves a session summary to `.claude/sessions/summary_YYYY-MM-DD.md`. Appends if today's file exists. Works in both Claude Code and Pi.
**Usage**:
- `/my-save` (Claude) or `/skill:my-save` (Pi) — auto-generates summary from conversation
- `/my-save focus on the auth refactor` — emphasizes specific topics
**Also**: Creates `state.md` + `architecture.md` if missing (analyzes project to populate). Updates `state.md` on every save (last activity, resume point, completed tasks). Copies transcript to `.claude/transcripts/`. Triggers MEMORY.md consolidation when 5+ unconsolidated sessions accumulate.
**Format**: Topics, entities, importance score, changes made, key decisions.
**Agent tag**: Each session is tagged `(via claude)` or `(via pi)` so you can tell which agent wrote it.
