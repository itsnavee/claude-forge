# System

Infrastructure, tooling, environment, and config issues.

### 2026-03-14 — statusline edits to repo don't take effect until synced
**Project**: claude-config
**Context**: Edited `claude-config/statusline.sh` (repo) but live statusline at `~/.claude/statusline.sh` was unchanged. User reported timezones not showing.
**Learning**: Claude Code uses `~/.claude/statusline.sh` directly. Editing the repo copy requires `cp` or `/my-claude-config-sync` to propagate. Always sync after editing.












### 2026-03-14 — session-start hook injecting 80 lines of context silently
**Project**: claude-config
**Context**: Token usage spiked after adding state.md/architecture.md pattern. Investigation found session-start hook was injecting last 80 lines of session summary into every new session, plus CLAUDE.md was loaded twice in claude-config repo.
**Learning**: Audit hook output sizes periodically. Changed to opt-in model — hook reports availability, user runs /my-catchup when needed.













### 2026-03-18 — Subagent JSONL output has line-number prefixes from Read tool
**Project**: my-project
**Context**: Tried to extract research-result JSON from background agent output file — Read tool adds line-number prefixes that break JSON parsing
**Learning**: When reading agent output files persisted by the system, strip line-number prefixes with sed before JSON parsing: `sed "s/^[[:space:]]*[0-9]*→//"`. Or use Bash cat directly instead of Read tool for raw JSONL.











### 2026-03-27 — cloud-init plain_text_passwd broken on Ubuntu Noble
**Project**: kubernetes-labs
**Context**: Setting up KVM VMs with cloud-init user-data, password auth failed despite correct config
**Learning**: On newer cloud-init (25.x), use `passwd` with a hashed value from `openssl passwd -6` plus `chpasswd: expire: false`. `plain_text_passwd` is unreliable.









### 2026-03-27 — sudo changes $HOME, breaks relative paths in scripts
**Project**: kubernetes-labs
**Context**: SSH key path used `$HOME/.ssh/...` but script runs via `sudo`, so `$HOME` became `/root`
**Learning**: In scripts that run as root via sudo, hardcode user paths or use `SUDO_USER` to resolve the real home directory. Never rely on `$HOME` for the invoking user's files.









### 2026-04-02 — browser-use MCP crashes entire Claude session with invalid schema
**Project**: my-project/<private>
**Context**: browser-use MCP tool schemas had oneOf/allOf/anyOf at top level, which Claude API rejects. Once the tool definition loaded, ALL requests failed — not just browser calls.
**Learning**: MCP servers with invalid tool schemas crash the entire session. Test each MCP server in isolation after installing. The error "tools.N.custom.input_schema: does not support oneOf" means remove that MCP immediately. Playwright MCP is the replacement.






### 2026-04-12 — ROUTING.md rules are unenforced
**Project**: my-project / claude-config
**Context**: Research session had zero `⚡ ClaudeForge: Using /...` announcements in 700+ turns despite ROUTING.md mandate; used `general-purpose` subagent_type when `scouts/github.md` was appropriate; skipped `/my-git-sync` for raw `git commit`.
**Learning**: Rules without hooks are comments. Convert mandates into PreToolUse hooks (block raw `git commit` where /my-git-sync exists; emit announcement automatically on Skill/Agent fire; register dedicated subagent_types). See claude-config/audits/2026-04-12-harness-quality/plan.md.





### 2026-04-14 — Amazon UK direct WebFetch returns HTTP 500/503 consistently
**Project**: my-project (<private> skill)
**Context**: Multiple sub-agents tried to fetch amazon.co.uk/dp/<ASIN> pages during deep-dive + price verification runs. 100% returned HTTP 500 or 503. CamelCamelCamel and Keepa both 403. Only reliable sources: brand direct sites, Google AI summaries (snippets), third-party retailers (John Lewis, Wildbounds).
**Learning**: Built a 7-step fallback ladder into <private> skill — brand site → Google snippet → camelcamelcamel → keepa → third-party retailer → brand direct → snippet-only. Also added verified-prices gate: spec-lock cannot run without data/verified-prices.json.




### 2026-05-24 — `psql` not installed on host; use `docker exec speak-postgres-dev psql` instead
**Project**: my-project
**Context**: tried `PGPASSWORD=... /usr/bin/psql -h localhost -p 7432 ...` to verify migrations; failed because psql isn't on the host.
**Learning**: when validating DB state in a containerized dev setup, route through the postgres container: `docker exec <pg-container> psql -U <user> -d <db> -c "..."`. No PGPASSWORD needed inside the container.



### 2026-05-24 — `doppler run -- python` fails; use `.venv/bin/uvicorn` directly
**Project**: my-project
**Context**: Tried `doppler run -- python -m uvicorn app.main:app` to inject secrets at boot. Failed: `Doppler Error: exec: "python": executable file not found in $PATH`. doppler run forks a subprocess that doesn't inherit the venv's $PATH.
**Learning**: When running a venv-installed tool under `doppler run`, invoke it via its full path: `doppler run -- .venv/bin/<binary>`. Or `doppler run -- bash -c 'source .venv/bin/activate && <cmd>'`.



### 2026-05-24 — Docker-network hostnames don't resolve from host (DATABASE_URL=speak-postgres:5432)
**Project**: my-project
**Context**: Doppler stg DATABASE_URL is `postgresql://...@speak-postgres:5432/...` — valid inside the docker-compose network, but host-side uvicorn boots fail with `gaierror: Name or service not known`.
**Learning**: For dual-context apps (host dev + docker-compose), either keep two DATABASE_URLs (one per Doppler config) or add host-side override at boot. Avoid hardcoding the Docker network hostname in the prd/stg config unless that config is *only* consumed from inside Docker.



### 2026-05-29 — rtk truncates curl output; verify with node fetch
**Project**: yumeloom
**Context**: `curl ... > file` repeatedly produced exactly ~201 bytes, looking like a broken/aborted page. It was the `rtk` proxy truncating curl output, not a real error — the page was healthy (chunked 200).
**Learning**: To inspect a local server's full HTML, use `node -e "fetch(url).then(r=>r.text())..."` instead of curl — rtk doesn't truncate node. Headless Playwright (via npx-cached module path) works for screenshots/measurements.



### 2026-06-21 — yt-dlp beats WebFetch for YouTube research
**Project**: my-project
**Context**: my-rate-app-idea skill notes "YouTube direct-fetch returns footer junk." WebFetch on @starterstory confirmed it. Installed yt-dlp via `uv tool install yt-dlp` (pip --user is blocked on this box).
**Learning**: For any YouTube-sourced research, pull the transcript: `yt-dlp --write-auto-subs --sub-lang en --skip-download --sub-format vtt`, strip VTT timestamps/dupes to plain text, feed the file path to sub-agents. No rate-limiting observed at ~5 videos. Far better than the skill's "search secondary coverage" fallback.

