---
name: my-fetch-article
description: Use when you need to fetch and extract a web article's content as clean markdown — handles blogs, docs, PDFs, arxiv. Also use for "fetch this article", "read this URL", or "extract content from".
argument-hint: "< URL >"
---

<!-- Pattern: Tool Wrapper -->

# /my-fetch-article — Web Article Fetcher

Fetches web article content and converts to clean markdown. Handles blogs, documentation, PDFs, and arxiv papers.

## Usage

- `/my-fetch-article https://example.com/blog/post` — fetch and display
- Called by research pipelines for non-GitHub web URLs

## Fetch Strategy

### Standard web pages
```
WebFetch "<url>" with prompt "Extract the full article content as clean markdown preserving all code blocks, images, headings, and lists. Remove navigation, ads, footers, and sidebars."
```

### PDF files
If URL ends in `.pdf` or content-type is `application/pdf`:
- Use the Read tool if downloaded locally
- Otherwise WebFetch with prompt focused on text extraction

### Arxiv papers
If URL matches `arxiv.org`:
- Fetch the abstract page, not the PDF
- Extract title, authors, abstract, key sections

## Output

```
# Article Title

**Source:** <url>
**Author:** <if available>
**Date:** <if available>

<article content in clean markdown>
```

When called by /my-research-targets, return raw content for classification.

## Gotchas

- Paywalled sites return partial content — check if the article seems truncated
- JavaScript-heavy sites (SPAs) may return empty content via WebFetch — try with a prompt that asks for visible text
- Very long articles (>5000 words) should include the full content — never truncate code blocks
- Some sites block automated fetching — try different user agents or xcancel as proxy

## Rules

- Read-only — never submit forms, create accounts, or bypass paywalls
- Preserve all code blocks, headings, lists — these are the highest-value content
- Strip navigation, ads, footers, cookie banners — only article content
- Never truncate code blocks even in very long articles
