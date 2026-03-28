---
name: my-classify-content
description: Use when you have fetched content (tweet, repo, article) and need to classify it against active projects, topics, and opportunities — produces structured research-result JSON. Also use for "classify this", "what projects does this help", or "analyze this for relevance".
argument-hint: "< content text or JSON >"
---

<!-- Pattern: Reviewer -->

# /my-classify-content — Content Classifier

Classifies fetched content against active projects, learning topics, side income opportunities, and content ideas. Produces structured `research-result` JSON.

## Prerequisites

- Content already fetched (via /my-fetch-tweet, /my-fetch-repo, /my-fetch-article, or provided inline)
- `~/code/github/my-project/OWNER-CONTEXT.md` exists

## Usage

- `/my-classify-content` — classifies content from the current conversation
- Called by `/my-research-targets` after fetching each URL
- Can be used standalone: paste content, get classification

## Behavior

### 1. Load Context
Read `~/code/github/my-project/OWNER-CONTEXT.md` for:
- Active projects with gaps
- Exploration areas and pain points
- Side income ideas and monetization patterns
- Content strategy and audience
- "What I'd Pay For" items (strongest signal)

### 2. Classify Against 5 Dimensions

Read `references/classification.md` for the full criteria.

**A. Active Projects** — match against each project's gaps and tech stack
**B. CLI Coding Setup** — MCP servers, skills, agent workflows, memory strategies
**C. Learning Topics** — cross-reference against active topics in `topics/index.md`
**D. Side Income** — concrete product/service angle only
**E. Content Ideas** — shareable angle with audience fit

### 3. Score & Output

Read `references/return-format.md` for the JSON schema.

Return a `research-result` JSON block with: url, type, title, status, views, improvements[], topic_learnings[], side_income[], content_ideas[], article, affected[].

**Impact scoring:**
- **High** = fills a blocking gap or actively painful
- **Medium** = useful new capability
- **Low** = nice to have
- **Reference only** = interesting but no clear application

## Gotchas

- Without OWNER-CONTEXT.md, classification is generic and low-value — always load it first
- New topics not in topics/index.md won't be matched — flag them as "potential new topic" in results
- Side income ideas must be specific (named product, named audience, named first step) — not generic "you could consult"
- Content ideas must have a clear shareable angle — not "this is interesting"

## Rules

- Never write speculative entries — only concrete, verified connections
- Project gap must exist before classifying as a project improvement
- Topic entry must add new knowledge — don't restate what's already in the topic file
- Use actual view counts for scoring — never estimate
- Return `[]` for dimensions with no matches, `null` for article if not worth saving
