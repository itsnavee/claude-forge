---
name: my-claude-config-sync
description: Use when you need to sync Claude Code configs between machines or back up your setup — bidirectional sync of skills, hooks, agents, and settings between host and claude-config git repo. Also use for "sync config", "backup my setup", or "push config changes".
argument-hint: "< push | pull | diff | (no arg: bidirectional sync) >"
---

# Claude Config Sync

Sync agent configuration between the git repo and this host. The repo is always at `$HOME/code/github/claude-config/`.

Supports both **Claude Code** (`~/.claude/`) and **Pi Coding Agent** (`~/.pi/agent/`). Auto-detects which are installed and syncs accordingly.

## What Gets Synced

### Claude Code (`~/.claude/`)

| Item | Direction | Notes |
|------|-----------|-------|
| `CLAUDE.md` | Bidirectional | Global rules + acceptance criteria gate |
| `agents/*.md` | Bidirectional | All agent personalities — auto-discovered |
| `skills/*/SKILL.md` | Bidirectional | All personal skills |
| `hooks/*.sh` | Bidirectional | Claude Code hooks |
| `settings.json` | Bidirectional | Claude Code settings |
| `statusline.sh` | Bidirectional | Statusline script |
| `projects/*.md` | Bidirectional | Projects index (port map, quick reference) |
| `projects/*/memory/*.md` | Bidirectional | Per-project memory files |
| `learning/*.md` | Bidirectional | Cross-session learnings — **append-merge** (entries never overwritten) |
| `context/*.md` | Bidirectional | Setup docs, environment notes |
| `quotes.json` | Bidirectional | Quotes collection |

### Pi Coding Agent (`~/.pi/agent/`)

| Item | Direction | Notes |
|------|-----------|-------|
| `pi/settings.json` | Bidirectional | Pi settings (model, compaction, retry) |
| `pi/extensions/*.ts` | Bidirectional | TypeScript extensions (session-hooks, etc.) |
| `pi/skills/*/SKILL.md` | Bidirectional | Pi skills + helper scripts |
| `pi/keybindings.json` | Bidirectional | Pi keybindings (if customized) |

### Claude Forge (`~/code/github/claude-forge`)

Public sanitized copy of claude-config. If the directory exists, changed files are copied from claude-config, scrubbed of sensitive patterns (private project names, usernames, paths, emails), then committed and pushed.

| Item | Direction | Notes |
|------|-----------|-------|
| `hooks/*.sh` | config → forge | All hooks |
| `agents/**/*.md` | config → forge | All agent personalities |
| `skills/*/SKILL.md` | config → forge | All skills + helper files |
| `learning/*.md` | config → forge | Sanitized learning files |
| `CLAUDE.md`, `settings.json`, etc. | config → forge | Top-level configs |

**Not synced to forge:** `context/`, `projects/` (contain private project data), `.claude/` (session data).

## Steps

1. **Validate** — confirm `$HOME/code/github/claude-config/` exists. If not, abort and tell the user to clone it first:
   ```bash
   git clone <repo-url> "$HOME/code/github/claude-config"
   ```

2. **Git sync (pull latest)** — `cd` into `$HOME/code/github/claude-config/` and run `/my-git-sync` to pull the latest remote changes before syncing configs. This ensures the repo is up-to-date so bidirectional sync compares against the latest state. If there are no local changes to commit, it will just pull and push.

3. **Detect installed agents** — run:
   ```bash
   echo "--- Agent Detection ---"
   [ -d "$HOME/.claude" ] && echo "CLAUDE=yes" || echo "CLAUDE=no"
   [ -d "$HOME/.pi/agent" ] && echo "PI=yes" || echo "PI=no"
   ```

4. **Claude Code sync** — if `~/.claude` exists:

   a. **Setup (if needed)** — check if `~/.claude/settings.json` exists. If NOT, run setup first:
   ```bash
   bash "$HOME/code/github/claude-config/claude-config-setup.sh"
   ```

   b. **Sync** — always run bidirectional sync:
   ```bash
   bash "$HOME/code/github/claude-config/claude-config-sync.sh"
   ```

5. **Pi Coding Agent sync** — if `~/.pi/agent` exists:

   a. **Setup (if needed)** — check if `~/.pi/agent/extensions/session-hooks.ts` exists. If NOT, run setup first:
   ```bash
   bash "$HOME/code/github/claude-config/pi-config-setup.sh"
   ```

   b. **Sync** — always run bidirectional sync:
   ```bash
   bash "$HOME/code/github/claude-config/pi-config-sync.sh"
   ```

6. **Report & push** — show the full output from both syncs. If either reports repo changes (files pulled from host to repo), `cd` into `$HOME/code/github/claude-config/` and run `/my-git-sync` to commit and push the changes.

7. **Claude-forge sync** — if `$HOME/code/github/claude-forge` exists:

   a. **Copy shared files** from claude-config to claude-forge:
   ```bash
   FORGE="$HOME/code/github/claude-forge"
   CONFIG="$HOME/code/github/claude-config"

   # Hooks, agents, scripts, top-level configs
   cp "$CONFIG"/hooks/*.sh "$FORGE/hooks/"
   cp -r "$CONFIG"/agents/* "$FORGE/agents/"
   cp "$CONFIG"/scripts/*.sh "$FORGE/scripts/" 2>/dev/null
   cp "$CONFIG"/{CLAUDE.md,RTK.md,settings.json,quotes.json,sanitize-patterns.conf} "$FORGE/"
   cp "$CONFIG"/{claude-config-setup.sh,claude-config-sync.sh,sync-all.sh} "$FORGE/"
   cp "$CONFIG"/statusline*.sh "$FORGE/" 2>/dev/null

   # Skills (entire directories)
   rsync -a --delete "$CONFIG/skills/" "$FORGE/skills/"

   # Learning files (need sanitization)
   mkdir -p "$FORGE/learning"
   cp "$CONFIG"/learning/*.md "$FORGE/learning/"
   ```

   b. **Sanitize** — scrub sensitive patterns from all text files in claude-forge:
   ```bash
   PATTERNS_FILE="$CONFIG/sanitize-patterns.conf"
   ```
   Read non-comment, non-directive lines from the patterns file. For each pattern, run `grep -rl` across the forge repo and `sed -i` to replace matches:
   - Private project names (my-project, my-project, etc.) → replace with `<private-project>`
   - `youruser` → `youruser`
   - `$HOME` or `$HOME` → `$HOME`
   - `you@` → `you@`
   - API key patterns → `<redacted>`

   **Do NOT sanitize:** `sanitize-patterns.conf` itself (it's the reference), `.git/`, binary files.

   **Important:** Only sanitize simple string patterns (project names, usernames, paths). Skip regex-heavy patterns (API keys, connection strings) — those won't appear in config files and sed can't handle them reliably. Focus on these specific replacements:
   ```bash
   # In all .md, .sh, .json files under $FORGE (excluding .git and sanitize-patterns.conf):
   sed -i 's|youruser|youruser|g'
   sed -i 's|$HOME|$HOME|g'  # after youruser replacement
   sed -i 's|$HOME|$HOME|g'
   sed -i 's|<your-email>|you@example.com|g'
   # For each private project name from patterns file:
   sed -i 's|<project-name>|my-project|g'
   ```

   c. **Diff, commit & push** — check `git -C "$FORGE" diff --stat`. If changes exist, commit with a message like `sync: update from claude-config` and push. Use `/my-git-sync` from within the forge directory.

   d. **Skip if not present** — if `$HOME/code/github/claude-forge` doesn't exist, just report "claude-forge not found, skipping" and continue.

## Gotchas

- Symlinked files don't sync correctly — the sync copies the symlink, not the target content
- settings.json contains machine-specific paths (e.g., hook commands) — don't blindly overwrite across machines

## Rules

- Always run with `bash` explicitly (not `sh`) for portability across Linux and macOS
- Do not modify the scripts themselves — they are version-controlled
- If a script fails, show the full error output and suggest: `git -C "$HOME/code/github/claude-config" pull`
- Newer file always wins in bidirectional sync — never force overwrite
- Skip agents that aren't installed — don't error, just report "not installed, skipping"

## New Machine Setup (from scratch)

```bash
git clone <repo-url> "$HOME/code/github/claude-config"

# Claude Code (if installed)
bash "$HOME/code/github/claude-config/claude-config-setup.sh"

# Pi Coding Agent (if installed — also installs pi if missing)
bash "$HOME/code/github/claude-config/pi-config-setup.sh"
```

Or just run `/my-claude-config-sync` (or `/skill:my-claude-config-sync` in Pi) — it detects what's installed and runs the right setup + sync automatically.

## Quick Help

**What**: Bidirectional sync for Claude Code, Pi Coding Agent, and claude-forge (sanitized public copy). Auto-detects what's installed.
**Usage**: `/my-claude-config-sync` (Claude) or `/skill:my-claude-config-sync` (Pi) — no arguments needed.
**Syncs**: CLAUDE.md, agents, skills, hooks, settings, extensions, project memories. If claude-forge exists, copies and sanitizes.
**New machine**: Clone claude-config repo first, then run this skill to install everything.
**Agents**: Syncs Claude Code if `~/.claude` exists, Pi if `~/.pi/agent` exists, claude-forge if `~/code/github/claude-forge` exists. Skips what's not installed.
