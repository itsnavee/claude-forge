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




