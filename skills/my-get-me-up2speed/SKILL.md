---
name: my-get-me-up2speed
description: Use when you need a quick overview of recent work across sessions — reads session summaries and presents colored output of what was done, key decisions, and current status. Also use for "what's been happening", "get me up to speed", or "session history".
argument-hint: "< N (number of sessions, default 3) >"
allowed-tools: Read, Glob, Grep, Bash(bash:*), Bash(echo:*), Bash(printf:*), Bash(cat:*), Bash(ls:*), Bash(head:*), Bash(tail:*), Bash(wc:*), Bash(jq:*)
---

# /my-get-me-up2speed

Show a colored, token-efficient summary of the last N sessions for the current project.

## Steps

1. **Parse argument** — extract N from user args. Default: 3. Max: 10.
2. **Find project root** — `git rev-parse --show-toplevel`
3. **Glob session summaries** — find `.claude/sessions/summary_*.md`, sort by date descending, take last N files
4. **Read summaries** — read all N summary files in parallel. These are the primary data source.
5. **Extract transcript extras** (optional, token-cheap) — for each session ID found in summaries, check if a matching transcript exists in `.claude/transcripts/`. If it does, run ONE grep per transcript for `"key_decision"\|"error"\|"blocker"` — do NOT read full transcripts. Skip if no transcripts exist.
6. **Check git log** — run `git log --oneline --since="<oldest-session-date>"` to get commits in the time range
7. **Output** — format and print using the colored template below via a single Bash `echo -e` or `printf` call

## Output Template

Use ANSI escape codes. Print via Bash — do NOT output as chat markdown.

```
Colors:
  CYAN    = \033[36m     — dates, timestamps
  YELLOW  = \033[33m     — headings, section titles
  GREEN   = \033[32m     — completed items, commits
  RED     = \033[31m     — incomplete/blockers
  MAGENTA = \033[35m     — decisions, key info
  DIM     = \033[2m      — dividers, metadata
  BOLD    = \033[1m      — emphasis
  RESET   = \033[0m
```

Format:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  🔄 UP TO SPEED — Last N Sessions
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[CYAN]📅 YYYY-MM-DD[RESET] [DIM]Session: <8-char-id>[RESET]
[YELLOW][BOLD]▸ <Task Title>[RESET]
  <1-2 line overview — from summary>

  [MAGENTA]⚡ Decisions:[RESET]
  • <key decision 1>
  • <key decision 2>

  [GREEN]✓ Changes:[RESET]
  • <file> — <what changed>

  [GREEN]✓ Commits:[RESET]
  • <hash> — <message>

  [RED]⚠ Status: Incomplete — <follow-up>[RESET]
  [GREEN]✓ Status: Complete[RESET]

[DIM]─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─[RESET]

... (repeat for each session, newest first) ...

[DIM]━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━[RESET]
[YELLOW][BOLD]📊 QUICK STATS[RESET]
  Sessions: N | Commits: X | Files changed: Y
  Active thread: <what's in progress from most recent session>
[DIM]━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━[RESET]
```

## Gotchas

- Duplicate of /my-catchup — both do the same thing. Consider using /my-catchup instead.

## Rules

### Token Budget
- **Summaries are the single source of truth.** They are concise by design (written by /my-save). Read them fully.
- **Never read full transcripts.** Transcripts can be 1MB+. Only grep for specific patterns if summaries lack detail on decisions/errors.
- **One Bash call for output.** Build the entire formatted string and print in a single echo/printf. Don't make multiple echo calls.
- **No LLM summarization of summaries.** The summaries are already summarized. Extract and reformat — don't re-summarize.
- **Skip empty sections.** If a session has no decisions, no commits, or no incomplete status — omit those subsections entirely.

### Session Parsing
- A single summary file may contain multiple sessions (separated by `---`). Each `## Session:` block is one session. Count these individually toward N.
- Sessions are ordered newest-first in output.
- Extract: Task title, overview, key decisions, changes, commits, status.

### Transcript Grep (optional enrichment)
- Only grep if transcript file exists for a session ID
- Pattern: `grep -o '"content":"[^"]*decision[^"]*"' <transcript> | head -3` — extract decision mentions
- If grep returns nothing useful, skip. Don't escalate to reading more.
- Total transcript grep budget: max 3 grep calls across ALL sessions.

### Git Log
- Use `--since` with the oldest session date from the N sessions
- `--oneline` only. Match commit hashes to sessions if possible.

### Edge Cases
- If fewer than N sessions exist, show all available and note it.
- If no sessions exist at all, print: "No session summaries found. Run /my-save to start tracking."
- If summaries have old format (no Topics/Entities/Importance), still parse Task/Changes/Status.

## Quick Help

**What**: Colored terminal summary of your last N sessions — what was done, key decisions, current status.
**Usage**:
- `/my-get-me-up2speed` — last 3 sessions (default)
- `/my-get-me-up2speed 5` — last 5 sessions
- `/my-get-me-up2speed 1` — just the latest session
**Token cost**: Low — reads only session summaries (already concise), optional transcript grep for decisions.
**Output**: ANSI-colored terminal output with dates, headings, dividers, and a quick stats footer.
