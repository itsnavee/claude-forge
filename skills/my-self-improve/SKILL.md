---
name: my-self-improve
description: Use when you want to analyze Claude session history and surface automation opportunities — finds repeated patterns, skill candidates, agent workflows, config improvements, and coding style fixes. Also use for "self improve", "analyze sessions", "what should I automate", or "find patterns".
argument-hint: "< all | alltime | (no arg: current project only) >"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(cat:*), Bash(find:*), Bash(python3:*), Bash(wc:*), Bash(date:*), Bash(head:*), Bash(stat:*), Agent
---

# Self-Improve

Analyze Claude Code session history to surface automation opportunities. Finds repeated patterns and writes actionable suggestions to `~/.claude/learning/self-improve.md`.

## Arguments

- No args: process **current project only** (detect via `git rev-parse --show-toplevel`, extract project name from path)
- `all`: process all projects incrementally (since each project's last-processed timestamp)
- `alltime`: process all projects, ignore timestamps (reprocess everything)

## State File

`~/.claude/learning/self-improve.md` — single source of truth. Contains:
- **Processed table**: one row per project with last-processed ISO timestamp
- **Suggestions**: one line per finding, deleted once implemented

**Format rules are in the file's HTML comments. Read them. Follow them.**

---

## Step 1 — Read State

Read `~/.claude/learning/self-improve.md`. Parse the Processed table into a map of `project -> timestamp`. Projects not in the table default to `2021-01-01T00:00:00Z`.

---

## Step 2 — Find Session Files

Session JSONL files live at `~/.claude/projects/<encoded-path>/`. The encoded path format is `-` + the absolute path with `/` replaced by `-`.

```bash
find ~/.claude/projects/ -name "*.jsonl" -not -path "*subagent*" 2>/dev/null
```

For each JSONL file:
1. Extract the project name from the directory path (reverse the encoding: last segment after `-Users-youruser-code-github-` or `-Users-youruser-data-code-github-`)
2. Get the file's modification time
3. If no args (current project mode), skip files not matching the current project
4. If not `alltime` mode, skip files whose mtime is older than the project's last-processed timestamp
5. Collect qualifying files grouped by project

If no qualifying files found, print "No new sessions to process since last run." and exit.

---

## Step 3 — Extract User Messages

For each qualifying JSONL file, extract user messages using python3:

```python
import json, sys
for line in open(sys.argv[1]):
    line = line.strip()
    if not line:
        continue
    try:
        obj = json.loads(line)
        if obj.get('type') == 'user':
            content = obj.get('message', {}).get('content', '')
            if isinstance(content, list):
                for c in content:
                    if isinstance(c, dict) and c.get('type') == 'text':
                        text = c['text']
                        # Skip system-reminder content
                        if '<system-reminder>' not in text:
                            print(text[:500])
            elif isinstance(content, str) and '<system-reminder>' not in content:
                print(content[:500])
    except:
        pass
```

Truncate each message to 500 chars — we need intent, not full content.

---

## Step 4 — Classify Patterns

Dispatch **haiku** subagents to classify. Batch sessions by project — one subagent per project (or per 10 sessions if a project has many).

Each subagent receives:
- The extracted user messages (concatenated, separated by `---`)
- The project name
- The existing suggestions from self-improve.md (to avoid duplicates)

**Subagent prompt:**

```
You are analyzing Claude Code session transcripts to find automation opportunities.

Project: {project_name}

Below are the user's messages from {N} sessions. Look for:

1. **SKILL candidates** — tasks the user triggers manually and repeatedly (e.g., "run tests then commit", "fetch this URL and classify it"). Must appear 2+ times.
2. **AGENT candidates** — multi-step workflows that could run autonomously (e.g., "research these repos, classify, write entries"). Must appear 2+ times.
3. **CONFIG candidates** — preferences the user states repeatedly that should be baked into CLAUDE.md (e.g., "don't add comments", "use integer cents"). Must appear 2+ times.
4. **CODING-STYLE candidates** — corrections the user makes repeatedly to Claude's output (e.g., "use early returns", "don't wrap in try/catch"). Must appear 2+ times.

Existing suggestions (do NOT duplicate these):
{existing_suggestions}

Rules:
- Only report patterns that appear 2+ times across sessions
- One line per finding: [type] "description" — seen Nx
- If nothing qualifies, return "NONE"
- Do not invent patterns. Only report what is clearly repeated in the transcripts.
- Maximum 10 findings per project

SESSION TRANSCRIPTS:
{messages}
```

---

## Step 5 — Update State File

After all subagents complete:

1. **Merge suggestions**: Collect all non-NONE findings. Deduplicate against existing suggestions in self-improve.md (fuzzy — if a new finding is essentially the same as an existing one, skip it). Append project names to existing suggestions if the same pattern is seen in a new project.

2. **Update timestamps**: For each processed project, set its timestamp to the newest JSONL file's mtime (ISO format). If the project already has a row, overwrite the timestamp. If not, add a new row.

3. **Write the file**: Read self-improve.md, update the Processed table and Suggestions section, write it back. Keep the HTML comments intact. Remove the `_default` row once real projects are added.

4. **Sync to repo**: Copy the updated file to the claude-config repo:
   ```bash
   cp ~/.claude/learning/self-improve.md ~/data/code/github/claude-config/learning/self-improve.md
   ```

---

## Step 6 — Present Results

Print a summary:

```
Self-Improve Analysis Complete
  Sessions processed: 12 across 4 projects
  New suggestions: 3

  [skill] "description" — seen 4x across project1, project2
  [config] "description" — seen 3x across project3
  [coding-style] "description" — seen 2x across project1

  Next: review suggestions, implement with relevant skill/config, then delete the line from self-improve.md
```

If no new suggestions found: "No new patterns detected. Your setup is well-optimized or more sessions needed."

---

## Gotchas

- JSONL files can be large (400K+). Extract user messages via python3 script, don't read the full file into Claude context.
- Some JSONL files are mostly hook progress messages with few user messages — skip files with <2 user messages.
- Subagent model must be **haiku** — this is a classification task on large text, not creative work.
- Session files from subagents (in `subagents/` directories) are excluded — they contain Claude-to-Claude dialogue, not user patterns.

## Quick Help

**What**: Analyzes your Claude session history to find repeated patterns worth automating as skills, agents, config rules, or coding style fixes.
**Usage**:
- `/my-self-improve` — process current project since last run
- `/my-self-improve all` — all projects since last run
- `/my-self-improve alltime` — all projects, reprocess everything
**Output**: Updates `~/.claude/learning/self-improve.md` with actionable suggestions, sorted by frequency.
**When**: Periodically (weekly-ish), or when you feel like you keep repeating yourself.
