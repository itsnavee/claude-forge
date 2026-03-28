---
name: my-research-targets
description: Use when researching any list of URLs (GitHub repos, X posts, web articles) to find actionable improvements for active projects, CLI coding setup, learning topics, side income opportunities, and content ideas worth posting on X/LinkedIn. Also replaces my-get-x-bookmarks.
argument-hint: "< URL file path | inline URL | --bookmarks | (no arg: research/targets.md) >"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(gh:*), Bash(curl:*), Bash(python3:*), Bash(twitter:*), Bash(mkdir:*), Bash(rm:*), Bash(jq:*), WebFetch, Agent, Skill(my-git-sync)
gate:
  type: cooldown
  duration: 20m
  reason: "Dispatches multiple scout agents per URL, writes to second-brain. Re-running on same targets file produces duplicate entries."
---

# Research Targets

Research any list of URLs — GitHub repos, X posts, web articles — then classify each against active projects, the CLI coding setup, learning topics, and side income opportunities. Write actionable entries to the right destination.

## Input

The user provides one of:
- A file path or inline URL list. Default: `~/code/github/second-brain/research/targets.md`.
- `--bookmarks` or `bookmarks` — auto-import from X bookmarks via twitter-cli (see Bookmark Mode below).

**File parsing:** read the file, extract all URLs (one per line, skip lines starting with `#`, skip blank lines). **Preserve annotation text after `<<`** — pass it to the subagent as user context for classification.

### Bookmark Mode

When invoked with `--bookmarks` (or no arguments and targets.md is empty):

Spawn a **background twitter-scout agent** (read `~/.claude/agents/scouts/twitter.md`, adopt identity) to export bookmarks while the main agent continues loading context:

```bash
twitter bookmarks --max 100 --json 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
for t in data.get('data', []):
    author = t.get('author', {}).get('screenName', 'unknown')
    tid = t.get('id', '')
    print(f'https://x.com/{author}/status/{tid}')
"
```

If twitter-cli fails (not installed or auth expired), warn the user and fall back to targets.md.

Deduplicate the extracted URLs against `research/mapping.md` before processing (same as file mode).

---

## Execution Model

Process URLs in **batches of 5**. For each batch:
1. Spawn 5 parallel subagents (one per URL) — each fetches, classifies, and returns structured results
2. Main agent collects all results from the batch
3. **Main agent writes batch results to disk** at `research/.cache/batch-<N>.md` (survives context compaction)
4. Main agent writes entries and saves articles (deduplicating via grep against existing file content)
5. Main agent updates mapping.md
6. Repeat for next batch

**Why disk persistence:** Results in memory get erased by context compaction after 3-5 batches. Cache is deleted after git sync.

**Startup cleanup:** `rm -rf ~/code/github/second-brain/research/.cache/ && mkdir -p ~/code/github/second-brain/research/.cache/`

---

## Step 1 — Load Global Mapping (dedup + re-analysis check)

Read `~/code/github/second-brain/research/mapping.md` and `~/code/github/second-brain/research/read-next/mapping.md`.

For each URL in the input list, check both mapping tables:

**Not in mapping** → process as new (via subagent).

**Already in mapping with a saved article** (status column is `saved→read-next`, filename present in read-next/mapping.md) → **re-analyse only**:
- Spawn a subagent with the saved article content (loaded from `~/code/github/second-brain/research/read-next/<filename>`) + project/topic context
- Subagent skips fetching — classifies the existing content against all current dimensions
- Subagent returns structured results; main agent writes any new entries
- The skill has grown since it was first processed — new topics and dimensions may yield entries that didn't exist before

**Already in mapping without a saved article** (GitHub repos, fetch-failed, reference-only) → skip entirely.

---

## Step 2 — Load Context (once, in main agent)

Read `~/code/github/second-brain/OWNER-CONTEXT.md` once. Inject its **full content** into every subagent's task prompt. It contains all active projects with gaps, explorations, coding setup, side income ideas, content strategy, and "What I'd Pay For" signals (~120 lines, replaces loading 14 separate files).

If a subagent needs deeper project context (rare), it should flag the need in its results and the main agent can verify by reading `~/code/github/second-brain/projects/<name>.md`.

---

## Step 3 — Research in Batches of 5

Group new URLs (and re-analyse URLs) into batches of 5. Process one batch at a time.

### Agent dispatch by URL type

Each subagent adopts a **scout agent identity** based on URL type. Read the agent file and include its full content in the subagent's task prompt:

| URL pattern | Agent identity | File |
|---|---|---|
| `github.com/<owner>/<repo>` | GitHub Scout | `~/.claude/agents/scouts/github.md` |
| `x.com/...` or `twitter.com/...` | Twitter Scout | `~/.claude/agents/scouts/twitter.md` |
| Everything else (web articles, PDFs, arxiv) | No scout — use WebFetch directly | — |

Inject the scout agent file content into the subagent prompt — do NOT duplicate those instructions here.

### For each batch: launch 5 parallel subagents (in background)

Each subagent receives: (1) scout agent file content, (2) URL or saved article content, (3) `<<` annotation if any, (4) OWNER-CONTEXT.md, (5) classification criteria from `references/classification.md`, (6) instruction to return `research-result` JSON.

**Run subagents in the background** (`run_in_background: true`). Subagents must NOT write files — they return all data inline.

**Web articles / other URLs** (no scout): use WebFetch with prompt "Extract the full article content as clean markdown preserving all code blocks, images, headings, and lists." Then classify using OWNER-CONTEXT.md and return the same `research-result` JSON format.

**Return Format:** Read `references/return-format.md` for the full JSON schema to inject into subagent prompts.

### After each batch completes

1. Collect all 5 subagent results.
2. **Write batch cache:** Save results to `research/.cache/batch-<N>.md` with all subagent outputs (URL, title, status, entries, article content). This survives context compaction.
3. Proceed to Steps 5–7 for this batch.
4. **Context check:** If context exceeds 200K tokens, compact before the next batch. Cache files ensure no data is lost. After compaction, re-read OWNER-CONTEXT.md and mapping.md to restore working context.
5. Repeat for next batch.

---

## Step 4 — Classification Criteria

**Classification:** Read `references/classification.md` for the full criteria to inject into subagent prompts.

---

## Step 5 — Write Entries

**Writing Entries:** Read `references/write-entries.md` for entry formats and dedup rules.

---

## Step 6 — Save Articles & Repo Summaries

**Saving Articles & Repos:** Read `references/save-articles.md` for save formats and scoring.

---

## Step 7 — Update Global Mapping (main agent, after each batch)

Append to `~/code/github/second-brain/research/mapping.md` for each processed URL:

```
| YYYY-MM-DD | <url> | <type> | <title> | <projects + topics affected, comma-separated | none> | <researched | reference-only | saved→read-next | fetch-failed> |
```

---

## Step 8 — Report

After all batches complete, print summary: total researched/re-analysed/skipped, per-URL status line (`✓ name → targets` or `— name → reference-only`), articles saved count, and entries written breakdown by category (improvements per project, CLI setup, topic learnings per slug, side income, content ideas by format).

---

## Step 9 — Cleanup & Commit

1. Delete the batch cache: `rm -rf ~/code/github/second-brain/research/.cache/`
2. Run `/my-git-sync` from `~/code/github/second-brain/` with message: `"research: <N> targets — projects: <list>, topics: <list>"`

---

## Gotchas

- Context compaction triggers at 200K tokens between batches — disk cache at `research/.cache/` ensures no data loss
- twitter-cli outputs debug text to stdout — always use `2>/dev/null`
- fxtwitter fails silently on some tweets — twitter-cli is primary, fxtwitter is fallback
- GitHub repos: shallow analysis from README alone — full analysis needs file tree + key files
- Subagent JSON output is unreliable — always validate before processing

## Rules

- Mapped URLs with saved article: re-analyse only (no re-fetch, no re-save)
- Mapped URLs without saved article: skip entirely
- Subagents return data only — never write files
- Grep-based dedup before every write (exact URL match + keyword title match)
- Never write speculative entries — only concrete, verified connections
- Project gap must exist before writing an improvement
- Topic entry must add new knowledge — no restating existing content
- Side income: named product/service, named audience, named first step
- Impact: High = blocking/painful; Low = nice to have
- GitHub repos: mapping only, no read-next article
- Fetch failures: log reason and skip, don't halt
- Never truncate code blocks in saved articles
- Pass `<<` annotations to subagents — user context for classification
- Use actual view counts for scoring — never estimate
- Write batch results to cache after each batch

## Quick Help

**What**: Researches URLs (GitHub repos, X posts, web articles) and classifies findings against projects, topics, side income, and content ideas.
**Usage**:
- `/my-research-targets` — processes `research/targets.md` (default)
- `/my-research-targets path/to/urls.txt` — custom URL file
- `/my-research-targets --bookmarks` — imports X bookmarks via twitter-cli
**Output**: Writes to `improvements/<project>.md`, `topics/<slug>.md`, `drafts/ideas.md`, `research/read-next/`, and `research/mapping.md`.
**Batching**: Processes 5 URLs in parallel per batch using twitter-scout and github-scout agents.
