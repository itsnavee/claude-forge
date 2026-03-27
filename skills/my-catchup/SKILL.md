---
name: my-catchup
description: Use when starting a session and need context on recent work — reads last N session summaries and presents a formatted overview of what was done, decisions made, and current status. Also use for "what did I do last time", "catch me up", or "recent sessions".
argument-hint: "< N (number of sessions, default 3) >"
allowed-tools: Read, Glob, Grep, Bash(bash:*), Bash(git:*)
---

# /my-catchup

Show a formatted, token-efficient summary of the last N sessions for the current project.

## Steps

1. **Parse argument** — extract N from user args. Default: 3. Max: 10.
2. **Find project root** — `git rev-parse --show-toplevel`
3. **Glob session summaries** — find `.claude/sessions/summary_*.md`, sort by date descending, take last N files
4. **Read summaries** — read all N summary files in parallel. These are the primary data source.
5. **Extract transcript extras** (optional, token-cheap) — for each session ID found in summaries, check if a matching transcript exists in `.claude/transcripts/`. If it does, run ONE grep per transcript for `"key_decision"\|"error"\|"blocker"` — do NOT read full transcripts. Skip if no transcripts exist.
6. **Check git log** — run `git log --oneline --since="<oldest-session-date>"` to get commits in the time range
7. **Output** — format and output directly as markdown text in your response (NOT via Bash tool)

## Output Template

Output as plain text directly in your chat response. Do NOT use Bash echo/printf. Do NOT use any markdown formatting that causes text highlighting — no bold, no italic, no inline code backticks, no blockquotes. Plain text only.

Line types:
- HEADING BORDERS (above/below title and stats): dotted line using · character, full width (80 chars)
- SESSION DIVIDERS (between sessions): solid continuous line using ─ character, full width (80 chars)
- Section labels (Decisions, Changes, Commits, Status): use emoji prefixes for color

Use this format:

```
· · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · ·
  🔄 UP TO SPEED — Last N Sessions
· · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · ·

YYYY-MM-DD  Session: <8-char-id>
▸ <Task Title>
  <1-2 line overview — from summary>

  ⚡ Decisions:
  - <key decision 1>
  - <key decision 2>

  ✅ Changes:
  - <file> — <what changed>

  📝 Commits:
  - <hash> — <message>

  🔴 Status: Incomplete — <follow-up>
  🟢 Status: Complete

────────────────────────────────────────────────────────────────────────────────

(repeat for each session, newest first)

· · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · ·
📊 QUICK STATS
  Sessions: N | Commits: X | Files changed: Y
  Active thread: <what's in progress from most recent session>
· · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · ·
```

## Gotchas

- Session summaries may not exist if /my-save wasn't run — check .claude/sessions/ first
- Multiple sessions on the same day append to the same file — parse all `## Session:` headers, not just file count

## Rules

### Token Budget
- **Summaries are the single source of truth.** They are concise by design (written by /my-save). Read them fully.
- **Never read full transcripts.** Transcripts can be 1MB+. Only grep for specific patterns if summaries lack detail on decisions/errors.
- **No LLM summarization of summaries.** The summaries are already summarized. Extract and reformat — don't re-summarize.
- **Skip empty sections.** If a session has no decisions, no commits, or no incomplete status — omit those subsections entirely.
- **Output directly as markdown text.** Do NOT use Bash tool for output — ANSI escape codes don't render in Claude Code's UI.

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

**What**: Formatted summary of your last N sessions — what was done, key decisions, current status.
**Usage**:
- `/my-catchup` — last 3 sessions (default)
- `/my-catchup 5` — last 5 sessions
- `/my-catchup 1` — just the latest session
**Token cost**: Low — reads only session summaries (already concise), optional transcript grep for decisions.
**Output**: Markdown-formatted text with dates, headings, dividers, and a quick stats footer.
