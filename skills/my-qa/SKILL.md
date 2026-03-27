---
name: my-qa
description: Use when you need to QA a running web app — launches a browser, explores pages, finds bugs, and generates regression tests for issues found. Also use for "QA the app", "test the UI", "browser test", or "find bugs in the frontend".
argument-hint: "< page/flow to test | URL override | (no arg: discover all) >"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Agent
---

# QA — Browser Testing with Bug Detection and Regression Tests

**Announce at start:** "Starting /my-qa — launching browser to explore the app and find bugs."

## Purpose

This is NOT test generation (my-smoke-test does that). This is NOT interactive Playwright scripting (webapp-testing does that). This skill **runs the app, explores it like a user, finds real bugs, fixes them, and writes regression tests** so the bugs don't come back.

## Prerequisites

Browser service must be available. Detection order:

1. **Docker Compose browser service** — check `docker-compose*.yml` for a `browser` service (Lightpanda or Playwright)
2. **Local Playwright** — `~/.claude/venv/bin/python -c "import playwright"` succeeds
3. **Playwright plugin** — if enabled in settings

If none available, tell the user and suggest: `docker compose up -d browser` or enable the Playwright plugin.

## Step 0: Resolve Project Root

Before any file operations, resolve the git repo root. All project-relative paths (`tests/`) are relative to this root, NOT `pwd`.

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
```

## Step 1: Detect App and Browser

```bash
# Find docker-compose file
COMPOSE_FILE=$(ls docker-compose*.yml docker-compose*.yaml 2>/dev/null | head -1)

# Detect running services and their ports
docker compose ps --format json 2>/dev/null | python3 -c "
import json, sys
for line in sys.stdin:
    svc = json.loads(line)
    name = svc.get('Service', svc.get('Name', ''))
    ports = svc.get('Publishers', [])
    for p in ports:
        pub = p.get('PublishedPort', 0)
        if pub: print(f'{name}: http://localhost:{pub}')
" 2>/dev/null
```

Read `architecture.md` and `state.md` to understand the app structure — routes, pages, key flows.

If the user passed a URL argument, use that instead of auto-detection.

## Step 2: Build Page Map

Before testing, understand what pages exist:

1. **Scan routes** — `Glob("**/pages/**/*.tsx", "**/app/**/page.tsx", "**/routes/**/*.py", "**/urls.py")`
2. **Read the main layout** to identify navigation links
3. **Build a page list** with expected elements per page

Output the page map:
```
Pages to test:
  / — landing page (expects: h1, nav, CTA button)
  /dashboard — main app (expects: sidebar, data table, auth required)
  /settings — user settings (expects: form, save button, auth required)
  /api/health — health check (expects: JSON response)
```

## Step 3: Explore and Test

For each page, run a Playwright script that:

1. **Navigates** to the page with `wait_until="networkidle"`
2. **Captures console errors** — any `console.error` is a bug candidate
3. **Checks HTTP status** — non-200 responses are bugs
4. **Checks key elements** — expected elements from Step 2 must be present
5. **Takes a screenshot** — save to `/tmp/qa/<page-slug>.png` for reference
6. **Tests interactive elements** — click buttons, fill forms, check responses
7. **Checks for visual issues** — elements overflowing, broken images (`img` with naturalWidth=0)

Use this pattern for each page:

```python
import json
from playwright.sync_api import sync_playwright

BROWSER_CDP = "http://localhost:9222"
APP_URL = "http://localhost:3000"  # adjust per project

with sync_playwright() as p:
    try:
        browser = p.chromium.connect_over_cdp(BROWSER_CDP)
    except Exception:
        browser = p.chromium.launch(headless=True)

    page = browser.new_page()

    errors = []
    page.on("console", lambda msg: errors.append({"type": msg.type, "text": msg.text}) if msg.type == "error" else None)

    response = page.goto(f"{APP_URL}/", wait_until="networkidle", timeout=15000)

    result = {
        "url": page.url,
        "status": response.status if response else None,
        "title": page.title(),
        "console_errors": errors,
        "broken_images": page.eval_on_selector_all("img", "imgs => imgs.filter(i => !i.naturalWidth).map(i => i.src)"),
    }

    page.screenshot(path="/tmp/qa/landing.png", full_page=True)
    print(json.dumps(result, indent=2))
    browser.close()
```

Adapt the script per page — auth-required pages need login first, API endpoints check JSON responses, forms need fill+submit tests.

## Step 4: Triage Findings

Classify each finding:

| Severity | Criteria | Action |
|----------|----------|--------|
| **BUG** | Console error, broken page, wrong status code, missing critical element | Fix + regression test |
| **WARN** | Broken image, slow load (>3s), minor element missing | Report, optional fix |
| **INFO** | Cosmetic, non-blocking | Report only |

## Step 5: Fix Bugs

For each BUG-severity finding:

1. **Trace the cause** — read the component/route code, check for obvious errors (missing imports, wrong props, broken API calls)
2. **Fix it** — minimal change, don't refactor surrounding code
3. **Verify the fix** — re-run the Playwright script for that page, confirm the bug is gone

If a bug requires a non-trivial fix (schema change, new dependency, architectural decision), don't fix it — log it as a blocker for the user.

## Step 6: Generate Regression Tests

For each bug that was fixed, generate a Playwright test that would catch the bug if it returned:

1. Write to `tests/e2e/test_regression_<date>.py` (or append if file exists)
2. Reuse the project's existing `conftest.py` if present (from my-smoke-test)
3. If no conftest exists, generate one (same pattern as my-smoke-test)

Each regression test must:
- Have a descriptive name: `test_dashboard_no_console_errors_after_load`
- Assert the specific condition that failed
- Be independent (no ordering dependencies with other tests)

## Step 7: Run All Tests

After fixes and new tests:

```bash
# Run the new regression tests
cd <project-root>
~/.claude/venv/bin/python -m pytest tests/e2e/ -v --tb=short 2>&1 | head -50
```

If tests fail, fix the test (not the app — the app was already verified in Step 5).

## Step 8: Report

```
QA Report — <project-name>
══════════════════════════════════════

Pages tested: 5/5
Screenshots: /tmp/qa/

Bugs found and fixed:
  [BUG] /dashboard — TypeError in console: Cannot read property 'map' of undefined
        Fix: src/components/DataTable.tsx:42 — added null check on data prop
        Test: tests/e2e/test_regression_2026-03-22.py::test_dashboard_no_console_errors

  [BUG] /settings — form submit returns 500
        Fix: src/api/settings.py:18 — missing field validation
        Test: tests/e2e/test_regression_2026-03-22.py::test_settings_form_submit_succeeds

Warnings:
  [WARN] /about — broken image: /img/team-photo.jpg (404)

Blocked (needs human):
  [BLOCK] /checkout — Stripe integration requires test API key

Regression tests: 2 new tests in tests/e2e/test_regression_2026-03-22.py
Test run: 2 passed, 0 failed
```

## Gotchas

- Auth-required pages need a login flow first — check for existing auth fixtures in conftest.py or generate one
- SPAs may need extra wait time after navigation — `networkidle` usually works, but some apps need `page.wait_for_selector()` on a specific element
- Lightpanda doesn't support all Chromium APIs (e.g., PDF rendering, some CSS features) — if a test fails on Lightpanda but the page works in a real browser, note it as a Lightpanda limitation, not a bug
- Docker networking: tests connect to `localhost:<port>` (port-mapped), not internal Docker hostnames
- Screenshots are saved to `/tmp/qa/` — they don't persist across reboots

## Rules

- Never modify test infrastructure (conftest.py, docker-compose.yml) unless broken — reuse what my-smoke-test generated
- Never fix cosmetic issues — only BUG severity gets fixed
- Never refactor code while fixing a bug — minimal change only
- Every bug fix MUST have a regression test — no fix without a test
- If the app isn't running, don't try to start it — tell the user to start it first
- Screenshots are for reference, not for the report — describe findings in text
- Blocked items go to the user, not to assumptions
