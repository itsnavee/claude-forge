---
name: my-second-brain-find-potential-improvements
description: Use when you want to find improvements for a project from research — cross-references project gaps with saved articles in second-brain, filters against existing implementations, and writes actionable entries to improvements/ files. Also use for "find improvements", "what can we adopt", or "check research for ideas".
argument-hint: "< project name | focus area | (no arg: current project) >"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Agent, Skill(git-push)
---

# Find & Incorporate Potential Improvements

Scan articles, cross-reference with project gaps, check what's already implemented, and surgically incorporate improvements into the right implementation docs.

## Constants

```
SECOND_BRAIN=~/code/github/second-brain
PROJECTS_DIR=$SECOND_BRAIN/projects
IMPROVEMENTS_DIR=$SECOND_BRAIN/improvements
ARTICLES_DIR=$SECOND_BRAIN/research/read-next
CODE_DIR=~/code/github
TODAY=<YYYY-MM-DD from current date>
```

---

## Step 0: Determine Scope

Detect where the skill was invoked from:

- **From a project root** (cwd is a git repo under `$CODE_DIR` that is NOT `second-brain`): Single-project mode. Only process that project.
- **From `$SECOND_BRAIN`**: Multi-project mode. Scan all git repos in `$CODE_DIR/` (run `ls` then filter to directories containing `.git/`). Exclude `second-brain`, `claude-config`, and any non-project repos (no matching file in `$PROJECTS_DIR/`).
- **From anywhere else**: Ask the user which project(s) to scan.

Store the list of `target_projects` — each entry is `{ name, repo_path, project_file, improvements_file }`.

---

## Step 1: Pull Latest Second-Brain

```bash
cd ~/code/github/second-brain && git pull --rebase origin main
```

If uncommitted changes, stash → pull → pop. If network fails, warn but continue.

---

## Step 2: Read Articles

Read ALL `.md` files in `$ARTICLES_DIR/` (excluding `mapping.md` and `url-list.txt`).

For each article, extract:
- **Filename**
- **Summary** (Claude's Summary section or first paragraph)
- **Topics** (tools, libraries, patterns, architectures, approaches)

Use an Explore subagent for this if article count > 20.

---

## Step 3: Per-Project Analysis (parallel subagents)

Launch one **Explore subagent per target project** (max 3 concurrent). Each subagent does:

### 3a. Read project summary
Read `$PROJECTS_DIR/<name>.md`. Extract gaps, unresolved problems, unstarted plans. Skip if archived.

### 3b. Read existing improvements
Read `$IMPROVEMENTS_DIR/<name>.md` if it exists. Note which suggestions were already made (to avoid duplicates) and which were marked as resolved/superseded.

### 3c. Build implementation context
Read the project's implementation docs to understand what's already built:
- Glob for `docs/**/*.md`, `docs/**/*.txt` in the project repo
- Read key files: architecture docs, phase/build plans, gaps/roadmap docs, key-decisions.md
- Grep for relevant patterns in source code when a suggestion touches specific functionality (e.g., if an article suggests a caching strategy, check if caching already exists)

### 3d. Cross-reference and filter
Compare each article against the project's gaps. For each potential match:

1. **Check if already suggested** — scan existing improvements file for the same article reference or same gap. Skip if duplicate.
2. **Check if already implemented** — search the project's code and docs for evidence the suggestion is already covered (or something better exists). Classify:
   - **SKIP** — project already implements this or something superior. Record reason.
   - **MERGE** — project partially covers this; the article adds a specific enhancement. Identify what's new.
   - **ADD** — project has a clear gap that this article addresses. Fully new suggestion.
3. **Validate connection** — must be concrete and specific, not generic advice.

### 3e. Return structured results
Each subagent returns:
```
project: <name>
suggestions:
  - title: <title>
    decision: SKIP | MERGE | ADD
    reason: <why this decision>
    gap: <exact gap from project summary>
    article: <filename>
    insight: <2-3 sentences>
    action: <specific next steps>
    impact: High | Medium | Low
    target_doc: <path to the implementation doc where this should be incorporated>
    target_section: <which section/heading in that doc>
```

---

## Step 4: Write to Second-Brain Improvements File

For each project with ADD or MERGE suggestions:

### Existing file → prepend new date section after H1, before existing sections
### New file → create with H1 and date section

Suggestion format:
```markdown
### <Title>
**Status**: pending
**Gap**: ...
**Article**: `<filename>`
**Insight**: ...
**Action**: ...
**Impact**: ...
```

For SKIP suggestions, do NOT add them to the improvements file. Instead, if the suggestion was previously listed as pending, update its status:
```markdown
**Status**: superseded — <reason>
```

---

## Step 5: Incorporate into Project Implementation Docs

For each ADD or MERGE suggestion, edit the target implementation doc in the project repo:

### Rules for incorporation:
- **Read the target doc first** — understand its structure, voice, and format
- **Find the right section** — don't append to the end blindly. Place the improvement where it logically belongs (e.g., a latency optimization goes in the performance section, not the auth section)
- **Match the doc's style** — if the doc uses numbered steps, add a numbered step. If it uses checkboxes, add a checkbox. If it uses tables, add a row.
- **Mark as AI-suggested** — prefix with `[ ]` checkbox if the doc uses them, or add `<!-- from: article-filename.md -->` comment so the source is traceable
- **For MERGE**: enhance the existing content rather than duplicating. Add the new insight/action inline where the partial coverage exists.
- **Keep it concise** — the implementation doc should have the actionable task, not the full analysis. The full analysis lives in the second-brain improvements file.

### If no clear target doc exists:
- Check for `docs/implementation/`, `docs/build-plans/`, `docs/plan/`, `docs/planning/` directories
- If a gaps/roadmap file exists (`GAPS-AND-ROADMAP.md`, `roadmap.md`), use that
- Last resort: append to `docs/key-decisions.md` under a "Pending Improvements" heading
- Never create new files — if no suitable doc exists, only write to second-brain

---

## Step 6: Report

Print a summary:

```
## Improvement Scan Complete

**Date**: <TODAY>
**Mode**: single-project (<name>) | multi-project (<N> projects)
**Articles scanned**: <count>

### <project-name>
- **Added**: <N> suggestions incorporated into implementation docs
  - <title> → `<target_doc_path>` (High)
  - <title> → `<target_doc_path>` (Medium)
- **Skipped**: <N> — already implemented or superseded
  - <title>: <brief reason>
- **Merged**: <N> — enhanced existing doc content
  - <title> → `<target_doc_path>`

### Notable Connections
- <1-2 sentence highlight of the most impactful finding>
```

---

## Step 7: Push Changes

### Second-brain repo
`cd` to `$SECOND_BRAIN` and invoke `/git-push`. Commit message: `"improvements: scan <TODAY> — <N> projects updated"`.

### Project repos (if implementation docs were edited)
For each project repo that was modified, `cd` to it and invoke `/git-push`. Commit message: `"docs: incorporate <N> improvement suggestions from research scan"`.

---

## Gotchas

- Stale articles in read-next/ may suggest improvements already implemented — always grep the project codebase to verify
- Large improvement files (>200 entries) slow down dedup checking

## Rules

- **Always use absolute paths** — this skill can run from any directory
- **Never fabricate connections** — if no article matches a gap, say so
- **Skip archived projects** — don't waste time analyzing dead projects
- **Append, don't overwrite** — existing improvement files must preserve history
- **Latest at top** — newest date section goes first, right after the H1
- **One file per project** — filename matches project name exactly
- **No empty files** — only create files for projects with real suggestions
- **Be specific** — "add tests" is not a suggestion; "use Vitest with the patterns from `<article>` to test the workflow engine" is
- **Respect what exists** — if the project already does something better, skip the suggestion and record why
- **Edit, don't dump** — implementation doc edits should feel like they were written by someone who read the doc, not appended by a bot
- **No new files in project repos** — only edit existing docs. New suggestions without a home go to second-brain only
- **Trace everything** — every incorporated suggestion links back to its source article

## Quick Help

**What**: Cross-references second-brain articles against project gaps, filters out already-implemented items, and writes actionable improvements into project docs.
**Usage**:
- Run from a **project root** — scans articles relevant to that project
- Run from **second-brain root** — scans all active projects
**Output**: Edits project implementation docs (ADD/MERGE suggestions) and writes analysis to `improvements/<project>.md`.
**Skips**: Archived projects, already-implemented suggestions.
