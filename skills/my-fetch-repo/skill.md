---
name: my-fetch-repo
description: Use when you need to fetch a GitHub repo's metadata, README, and file tree — wraps gh CLI. Returns structured data. Also use for "check this repo", "what is this repo", or "fetch repo info".
argument-hint: "< owner/repo | GitHub URL >"
---

<!-- Pattern: Tool Wrapper -->

# /my-fetch-repo — GitHub Repository Fetcher

Fetches repo metadata, README content, and file tree using gh CLI. Returns structured data for standalone use or as input to /my-research-targets pipeline.

## Prerequisites

- `gh` CLI installed and authenticated (`gh auth status`)

## Usage

- `/my-fetch-repo https://github.com/owner/repo` — fetch and display
- `/my-fetch-repo owner/repo` — fetch by owner/repo
- Called by `/my-research-targets` for GitHub URLs

## Fetch Strategy

### Step 1 — Metadata (always)
```bash
gh repo view <owner>/<repo> --json name,description,stargazerCount,forkCount,licenseInfo,primaryLanguage,topics,url,createdAt,updatedAt
```

### Step 2 — README (always)
```bash
gh api repos/<owner>/<repo>/readme --jq '.content' | base64 -d | head -200
```

### Step 3 — File tree (for repos with >100 stars)
```bash
gh api 'repos/<owner>/<repo>/git/trees/main?recursive=1' --jq '.tree[] | select(.type=="blob") | .path' | head -80
```

### Fallback
If `gh` fails (rate limit, private repo):
```
WebFetch "https://github.com/<owner>/<repo>" with prompt "Extract repo description, stars, language, and README summary"
```

## Output

```
## owner/repo
Stars: 12,345 | License: MIT | Language: TypeScript
Topics: agent, cli, mcp
Created: 2025-06-15 | Updated: 2026-03-18

### README (first 200 lines)
<readme content>

### File Tree (top 80 files)
<file paths>
```

When called by /my-research-targets, return raw data for classification.

## Gotchas

- `gh api` has rate limits (5000/hr authenticated) — batch requests when fetching multiple repos
- File tree endpoint returns `main` branch by default — some repos use `master`; fallback: `gh api repos/<owner>/<repo> --jq '.default_branch'`
- Large READMEs (>200 lines) should be truncated — head -200 is sufficient for classification
- Private repos return 404 — check access before reporting as "not found"

## Rules

- Read-only — never star, fork, create issues, or modify anything
- Always check `gh auth status` before first use in a session
- Truncate README to 200 lines and file tree to 80 files to stay within context budget
