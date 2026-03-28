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
**Project**: my-project-5
**Context**: Planned 11 tasks but 4 were already implemented (wishlist, SKU display, order number, templates gallery, security audit)
**Learning**: Always grep/search the codebase BEFORE adding tasks to a loop. Progress docs can be stale. The codebase is the source of truth.






### 2026-03-21 — loop continuity
**Project**: my-project-5
**Context**: User pointed out I was stopping every 3-5 tasks to output summaries and wait for "continue"
**Learning**: In /my-loop, don't pause between tasks for summaries. Execute continuously until the list is exhausted or context runs out. Checkpoint via git commits, not conversation pauses.






### 2026-03-21 — CF Tunnel beats Hetzner LB for zero-inbound VPS
**Project**: my-project
**Context**: Evaluated Hetzner LB vs CF LB for production. Hetzner LB requires VPS on private network but Hetzner has no managed NAT gateway — VPS can't make outbound API calls without a public IP or extra NAT VPS.
**Learning**: CF Tunnel (free) + CF LB ($5/mo) is better: tunnel creates outbound-only connection, VPS keeps public IP but firewalls ALL inbound. Result: zero open ports + full outbound connectivity. Hetzner LB adds complexity for no security benefit.




