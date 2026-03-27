---
name: my-fetch-tweet
description: Use when you need to fetch a tweet's content, metrics, and article text — wraps twitter-cli with fxtwitter fallback. Returns structured data. Also use for "get this tweet", "fetch tweet", or "what does this tweet say".
argument-hint: "< tweet URL | tweet ID >"
---

<!-- Pattern: Tool Wrapper -->

# /my-fetch-tweet — Twitter/X Content Fetcher

Fetches tweet content, metrics, and article text using twitter-cli (primary) with fxtwitter API fallback. Returns structured data for standalone use or as input to /my-research-targets pipeline.

## Prerequisites

- `twitter` CLI: `uv tool install twitter-cli`
- Auth: `TWITTER_AUTH_TOKEN` + `TWITTER_CT0` env vars set

## Usage

- `/my-fetch-tweet https://x.com/user/status/123456` — fetch and display
- `/my-fetch-tweet 123456` — fetch by tweet ID
- Called by `/my-research-targets` for X/Twitter URLs

## Fetch Strategy

### Step 1 — twitter-cli (primary)
```bash
twitter tweet <tweet-id> --json 2>/dev/null
```
Parse: `.data[0].text`, `.data[0].author.screenName`, `.data[0].metrics.views`, `.data[0].metrics.bookmarks`, `.data[0].urls[]`.

### Step 2 — fxtwitter API (fallback)
```bash
curl -s "https://api.fxtwitter.com/<user>/status/<id>"
```
Parse: `.tweet.text`, `.tweet.author.screen_name`, `.tweet.views`, `.tweet.bookmarks`, `.tweet.article`.

### Step 3 — xcancel (last resort)
```
WebFetch "https://xcancel.com/<user>/status/<id>" with prompt "Extract the tweet text, author, and any linked content"
```

All three fail → return `fetch-failed` with reason.

### Thin Tweet Detection
If text < 50 chars AND contains t.co URL:
1. Follow redirect: `curl -sL -o /dev/null -w '%{url_effective}' "<t.co-url>"`
2. WebFetch the destination
3. Merge destination content with tweet metadata

### Article Detection
If twitter-cli returns `.data[0].article` or fxtwitter returns `.tweet.article`:
- Extract article title, blocks (headers, paragraphs, lists)
- Convert to clean markdown preserving structure

## Output

Return structured data:
```
Author: @username
Views: 123,456 | Bookmarks: 1,234 | Likes: 567
Type: tweet | article | thread

Content:
<tweet text or article markdown>
```

When called by /my-research-targets, return the raw data for classification.

## Gotchas

- twitter-cli outputs debug text to stdout — always use `2>/dev/null`
- fxtwitter fails silently on some tweets — check HTTP status
- Article blocks may contain `atomic` type (images) — render as `[media/image]`
- Rate limits: twitter-cli handles retries internally, but fxtwitter has no retry
- Thread detection: if tweet has `.data[0].conversation_id` different from tweet ID, it's part of a thread — fetch the thread

## Rules

- Read-only — never post, like, retweet, follow, or modify anything
- Always try twitter-cli first — it handles auth, anti-detection, retries
- Always use `--json` flag and `2>/dev/null` for twitter-cli
- Return actual view counts — never estimate
