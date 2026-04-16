# Algorithm

Wrong approaches, over-engineering, missed requirements, process mistakes.

### 2026-03-18 — Integer cents over float credits for billing
**Project**: my-project
**Context**: Compared quota systems across 3 projects (SpeakLaunch, Nancy, Sawabi). SpeakLaunch and Nancy both used float credits, Sawabi used integer cents.
**Learning**: Always use integer cents for money/credits — float precision drift accumulates over thousands of transactions. Sawabi's `margin_cents GENERATED ALWAYS AS (billed - cogs) STORED` pattern gives free margin tracking per row.











### 2026-03-18 — Cost optimizations at zero scale save zero dollars
**Project**: my-project
**Context**: Vetted 17 improvement candidates. 8 were cost optimization items (Moonshine STT, Telnyx migration, OTEL tracking, etc.) proposed before having any customers.
**Learning**: At 0 customers, cost optimization is pure waste. Deepgram at 100 onboardings = $0.22/month — the Docker sidecar RAM costs more. Defer cost work until reaching specific revenue triggers ($500/month Twilio, 20+ tenants for observability).











### 2026-03-18 — Codebase reality check before planning
**Project**: my-project
**Context**: Planned 11 tasks but 4 were already implemented (wishlist, SKU display, order number, templates gallery, security audit)
**Learning**: Always grep/search the codebase BEFORE adding tasks to a loop. Progress docs can be stale. The codebase is the source of truth.









### 2026-03-21 — loop continuity
**Project**: my-project
**Context**: User pointed out I was stopping every 3-5 tasks to output summaries and wait for "continue"
**Learning**: In /my-loop, don't pause between tasks for summaries. Execute continuously until the list is exhausted or context runs out. Checkpoint via git commits, not conversation pauses.









### 2026-03-21 — CF Tunnel beats Hetzner LB for zero-inbound VPS
**Project**: my-project
**Context**: Evaluated Hetzner LB vs CF LB for production. Hetzner LB requires VPS on private network but Hetzner has no managed NAT gateway — VPS can't make outbound API calls without a public IP or extra NAT VPS.
**Learning**: CF Tunnel (free) + CF LB ($5/mo) is better: tunnel creates outbound-only connection, VPS keeps public IP but firewalls ALL inbound. Result: zero open ports + full outbound connectivity. Hetzner LB adds complexity for no security benefit.








### 2026-04-01 — Research existing tools before building custom
**Project**: my-project
**Context**: Almost built a custom browser scraping layer for the <private> plugin before discovering browser-use has a built-in MCP server mode and Lightpanda has native MCP command
**Learning**: Always search for existing MCP servers and tool integrations before writing custom browser automation. The ecosystem is growing fast — `uvx browser-use --mcp` and `lightpanda mcp` replaced weeks of custom CDP code with one-line installs.



### 2026-04-02 — Pencil MCP design-to-code workflow
**Project**: my-project
**Context**: First time converting a full Pencil .pen design to a Next.js template. Explored all 6 pages, read node trees, took screenshots, extracted variables.
**Learning**: The effective workflow is: get_editor_state → get_variables → batch_get (readDepth 3-4, resolveInstances+resolveVariables) → get_screenshot for visual verification → implement in code. Don't try to read all pages at once — batch by 2-3 pages to avoid context overflow. Screenshots are essential for catching layout issues the node data won't reveal.



### 2026-04-02 — acceptance criteria before testing catches structural gaps
**Project**: my-project
**Context**: Ran <private> plugin tests on Apr 1 without acceptance criteria. Tests "passed" but missed: no file persistence, no scorecard verdict, fabricated frequency data. Created acceptance-criteria.md on Apr 2 — immediately surfaced 16 gaps.
**Learning**: Write acceptance criteria BEFORE testing, not after. "It produced output" is not the same as "it produced correct output." The skeptic agent found 7 critical issues that manual testing missed because no one defined what "correct" meant.



### 2026-04-12 — Bash heredoc vs Edit for large-file appends
**Project**: my-project
**Context**: Appended entries to 8 large improvement/topic markdown files via `cat >> file <<EOF`. Skills docs prefer Read+Edit with unique-match, but for tracked markdown files >20KB the heredoc append was faster with no semantic risk.
**Learning**: For pure append operations to existing markdown files, `cat >> file <<EOF` is legitimate. Reserve Edit for in-place modification. Document this exception in CLAUDE.md to avoid future guilt.



### 2026-04-14 — Alibaba prices are not factory cost
**Project**: my-project (<private> skill)
**Context**: Built Variant A/B pricing stacks using $7-12 USD FOB floor derived from Alibaba listings. User pushed back: real Pakistan factory ex-factory is 1,000-1,500 PKR (~$3.50-5.50 USD), roughly half the Alibaba quote. Had to rewrite the pricing stack files 4 times as user corrected each assumption.
**Learning**: For sellers with local sourcing knowledge in the production country, Alibaba listings are inflated trader/middleman prices — discount 40-60% to estimate real FOB floor. Always ASK the seller "do you have local sourcing knowledge?" before applying standard <private> cost assumptions. Same principle applies to samples (£0 if local pickup), branding (£0 if DIY), photography (£0 if DIY in source country). Codified as skill rule.


### 2026-04-14 — Margin % is misleading; use ROI at MOQ
**Project**: my-project (<private> skill)
**Context**: Built initial spec-lock with "30% post-PPC margin" as the primary evaluation metric. User asked for ROI on capital deployed instead. Switching lenses dramatically changed the framing: 178% ROI per 6-month cycle at £1,096 capital beats a 30% margin comparison.
**Learning**: For <private> products, always evaluate at MOQ-level capital deployment + ROI with sell-through sensitivity tables, NOT just margin %. Margin % alone is misleading (30% on £5 needs 100x scale; 20% on £45 is meaningful per unit). Codified in <private> skill as required output in every spec-lock.

