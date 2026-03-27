---
name: my-write-research-entries
description: Use when you have classified research results and need to write entries to improvements/, topics/, drafts/, and research/ files — handles dedup, formatting, and mapping updates. Also use for "write the entries", "save research results", or "update improvements".
argument-hint: "< path to results | cached batch >"
---

<!-- Pattern: Pipeline -->

# /my-write-research-entries — Research Entry Writer

Takes classified `research-result` JSON and writes entries to the correct destination files in second-brain. Handles dedup, GitHub markdown formatting, article saving, and mapping updates.

## Prerequisites

- Classified results (from /my-classify-content or /my-research-targets)
- Working directory or explicit path to `~/code/github/second-brain/`

## Usage

- `/my-write-research-entries` — writes entries from classified results in conversation
- Called by `/my-research-targets` after each batch of classifications

## Behavior

### Step 1 — Dedup Check
Before writing each entry:
1. **Exact URL match**: `grep -c "<source-url>" <destination-file>` — skip if found
2. **Keyword title match**: `grep -i "<2-3 distinctive words>" <destination-file>` — read 5 lines of context if found, skip if same gap/insight covered

### Step 2 — Write Entries

Read `references/entry-formats.md` for the exact templates.

**Destinations:**
- **Project improvements** → `improvements/<project>.md`
- **CLI setup** → `improvements/cli-coding-setup.md`
- **Topic learnings** → `topics/<slug>.md` under `## Key Learnings`
- **Side income** → `topics/side-income-ideas.md` under `## Ideas Worth Exploring`
- **Content ideas** → `drafts/ideas.md` under `## Ideas Backlog`

All entries append under current date section `## YYYY-MM-DD`. Create the section if missing.

**GitHub markdown rule:** Every `**Field**: value` line MUST end with two trailing spaces for line breaks.

### Step 3 — Save Articles
For X posts and web articles with article content (not GitHub repos):
- Save to `research/read-next/YYYY-MM-DD-<slug>.<score>.md`
- Score 1-10 based on actual view count
- Append to `research/read-next/mapping.md`

### Step 4 — Save Repo Summaries
For GitHub repos with `repo_summary`:
- Append to `research/repos.md`
- Dedup: `grep -c "<owner>/<repo>" research/repos.md`

### Step 5 — Update Global Mapping
Append to `research/mapping.md`:
```
| YYYY-MM-DD | <url> | <type> | <title> | <affected> | <status> |
```

## Gotchas

- Write tool fails with "file not read" on files from previous sessions — always Read first, then Edit to append
- Large improvement files (>200 entries) slow down grep dedup — consider using head_limit on grep
- Missing date sections cause entries to append at wrong position — always check for `## YYYY-MM-DD` first
- Trailing spaces for GitHub line breaks are invisible and easy to forget — verify with `cat -A` if unsure

## Rules

- Never duplicate entries — grep-based dedup is mandatory before every write
- Never truncate code blocks in saved articles
- Article scoring uses actual view counts — never estimate
- GitHub repos get mapping only, no read-next article
- Create files with standard headers if missing
