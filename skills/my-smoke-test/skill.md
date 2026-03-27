---
name: my-smoke-test
description: Use when a project needs e2e smoke tests — generates Playwright test files that live in the project repo and run inside Docker. Also use for "write smoke tests", "add e2e tests", "generate tests for the UI", or "test the app".
argument-hint: "< URL | service name >"
---

<!-- Pattern: Generator + Reviewer -->

# /my-smoke-test — E2E Test Generator

Generates Playwright e2e smoke tests that live in the project repo, run inside the project's Docker stack, and work on any machine. The skill writes test files — the project infrastructure runs them.

## Usage

- `/my-smoke-test` — generate tests for the current project
- `/my-smoke-test src/pages/booking.tsx` — generate tests for a specific page/flow

## What Gets Generated

```
<project-root>/
  tests/
    e2e/
      conftest.py              ← browser setup (Lightpanda CDP → Chromium fallback)
      test_smoke.py            ← core smoke tests (loads, no errors, key elements)
      test_<flow>.py           ← flow-specific tests (booking, auth, checkout, etc.)
  docker-compose.yml           ← updated with browser service (if not present)
```

## Behavior

### Step 1 — Analyze the Project

Read the project to understand what to test:
1. Read `architecture.md` or `state.md` for app structure
2. Read `docker-compose.yml` for existing services
3. Scan routes/pages: `Glob("**/pages/**/*.tsx", "**/app/**/page.tsx", "**/routes/**/*.py")`
4. Read the main layout/landing page to identify key elements
5. Check if `tests/e2e/` already exists — if so, read existing tests to avoid duplicates

### Step 2 — Add Browser Service to Docker Compose

If `docker-compose.yml` doesn't have a browser service, add it:

```yaml
  browser:
    image: lightpanda/browser:latest
    ports:
      - "9222:9222"
    restart: unless-stopped
```

If Lightpanda image isn't available or fails, fall back to:
```yaml
  browser:
    image: mcr.microsoft.com/playwright:v1.50.0-noble
    command: npx playwright run-server --port 9222
    ports:
      - "9222:9222"
```

### Step 3 — Generate conftest.py

Create `tests/e2e/conftest.py` with browser connection logic:

```python
import pytest
import asyncio
from playwright.async_api import async_playwright

# Browser service URL — connects to Docker service or localhost
BROWSER_CDP = "http://localhost:9222"
# App URL — adjust per project
APP_URL = "http://localhost:3000"

@pytest.fixture
async def page():
    async with async_playwright() as p:
        try:
            browser = await p.chromium.connect_over_cdp(BROWSER_CDP)
        except Exception:
            browser = await p.chromium.launch(headless=True)
        context = await browser.new_context()
        page = await context.new_page()
        yield page
        await context.close()
        await browser.close()

@pytest.fixture
def app_url():
    return APP_URL
```

Adjust `APP_URL` based on the project's docker-compose port mapping.

### Step 4 — Generate Core Smoke Tests

Create `tests/e2e/test_smoke.py` with baseline assertions:

```python
import pytest

@pytest.mark.asyncio
async def test_page_loads(page, app_url):
    """App loads and returns 200."""
    response = await page.goto(app_url, wait_until="networkidle")
    assert response.status == 200

@pytest.mark.asyncio
async def test_no_console_errors(page, app_url):
    """No JavaScript console errors on load."""
    errors = []
    page.on("console", lambda msg: errors.append(msg.text) if msg.type == "error" else None)
    await page.goto(app_url, wait_until="networkidle")
    assert len(errors) == 0, f"Console errors: {errors}"

@pytest.mark.asyncio
async def test_key_elements_present(page, app_url):
    """Critical UI elements are visible."""
    await page.goto(app_url, wait_until="networkidle")
    # Adjust selectors per project
    assert await page.query_selector("h1"), "No h1 heading found"
    assert await page.query_selector("nav, header"), "No navigation found"
```

### Step 5 — Generate Flow-Specific Tests

Based on Step 1 analysis, generate test files for key user flows:

**For each critical flow** (e.g., booking, auth, checkout):
1. Read the page/component code to identify interactive elements
2. Map the user journey (click sequence, form fills, expected outcomes)
3. Write test with `page.click()`, `page.fill()`, `page.wait_for_selector()`
4. Save as `tests/e2e/test_<flow>.py`

### Step 6 — Add Run Instructions

Create or update `tests/e2e/README.md`:

```markdown
# E2E Smoke Tests

## Run locally
```bash
# Start services (includes browser)
docker compose up -d

# Run tests
pip install pytest pytest-asyncio playwright
pytest tests/e2e/ -v
```

## Run in CI
```yaml
- name: E2E tests
  run: |
    docker compose up -d
    pip install pytest pytest-asyncio playwright
    pytest tests/e2e/ -v
    docker compose down
```
```

### Step 7 — Report

```
Smoke Tests Generated — <project-name>
═══════════════════════════════════════
Files created:
  ✓ tests/e2e/conftest.py (browser setup, CDP connection)
  ✓ tests/e2e/test_smoke.py (3 baseline tests)
  ✓ tests/e2e/test_booking.py (5 flow tests)
  ~ docker-compose.yml (browser service added)
  ✓ tests/e2e/README.md (run instructions)

Run: docker compose up -d && pytest tests/e2e/ -v
```

## Gotchas

- Always use `wait_until="networkidle"` for SPAs (Next.js, React) — `domcontentloaded` fires too early
- Lightpanda doesn't support all Chromium APIs — conftest.py has automatic fallback
- Docker Compose service name matters — tests connect to `localhost:9222` (port-mapped), not `browser:9222` (unless running inside Docker network)
- Auth flows need explicit handling — generate a `login_fixture` in conftest.py if the app requires auth
- Generated selectors may break on UI changes — use `data-testid` attributes when available, fall back to semantic selectors (`role`, `text`)
- `pytest-asyncio` is required — add to project's dev dependencies

## Rules

- Tests MUST live in the project repo (`tests/e2e/`) — not in `~/.claude/`
- Tests MUST run inside Docker (browser service) — not depend on local browser binaries
- Generate `conftest.py` first — all tests share the browser fixture
- One test file per flow — keep tests focused and independent
- Use semantic selectors over brittle CSS selectors — `page.get_by_role()`, `page.get_by_text()`
- Never hardcode credentials in tests — use env vars or fixtures
- Always include the 3 baseline smoke tests (loads, no errors, key elements)
