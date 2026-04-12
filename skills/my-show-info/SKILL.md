---
name: my-show-info
description: Use when you need to check your Claude Code setup — quick lookup for installed skills, hooks, agents, session info, settings, and plugins. Also use for "show info", "what skills do I have", "list hooks", or "my setup".
argument-hint: "< skill-name | hooks | agents | session | settings | plugins | help >"
allowed-tools: Read, Glob, Grep, Bash(cat:*), Bash(ls:*), Bash(head:*), Bash(wc:*)
---

# /my-show-info

Fast, low-token lookup for your Claude Code setup. Prints file contents or short summaries — avoids heavy LLM processing.

## How It Works

Parse the argument. Match it against the lookup table below. Execute the matching action.

**Default behavior**: print raw file contents. Only summarize when the argument explicitly asks for it or when aggregating multiple files.

---

## Lookup Table

### Skills

| Argument | Action |
|----------|--------|
| `<skill-name>` (e.g., `my-prompt`, `my-git-sync`) | Read `~/.claude/skills/<skill-name>/SKILL.md`, extract and print **only the `## Quick Help` section**. Do not read or process the rest of the file. |
| `skills` or `all-skills` | List all skill directories under `~/.claude/skills/` with each skill's `description` from frontmatter (one line per skill). |

### Hooks

| Argument | Action |
|----------|--------|
| `<hook-filename>` (e.g., `session-start`, `cost-tracker`) | Read `~/.claude/hooks/<name>.sh` and print it. |
| `hooks` or `all-hooks` | List all hooks from `~/.claude/hooks/` with the first comment line from each `.sh` file as its description. |
| `stop-hooks` | Read `~/.claude/settings.json`, find all hooks under `"Stop"`, print each hook's filename and read the first 5 lines of each script. |
| `start-hooks` | Same as above but for `"SessionStart"`. |
| `pre-tool-hooks` or `pretool-hooks` | Same for `"PreToolUse"`. |
| `post-tool-hooks` or `posttool-hooks` | Same for `"PostToolUse"`. |
| `compact-hooks` or `precompact-hooks` | Same for `"PreCompact"`. |

### Agents

| Argument | Action |
|----------|--------|
| `<agent-name>` (e.g., `skeptic`, `github-scout`) | Read `~/.claude/agents/<name>.md` and print it. |
| `agents` or `all-agents` | Read `~/.claude/agents/README.md` and print it. |

### Session

| Argument | Action |
|----------|--------|
| `current-session` or `session` | Find the most recent `summary_*.md` in the **current project's** `.claude/sessions/` directory. Print it raw — no summarization. |
| `sessions` or `all-sessions` | List all session summary files for the current project with dates and file sizes. |
| `memory` or `MEMORY.md` | Find and print the MEMORY.md for the current project from `~/.claude/projects/<path>/memory/MEMORY.md`. |

### Settings & Config

| Argument | Action |
|----------|--------|
| `settings` | Print `~/.claude/settings.json`. |
| `plugins` | Read `~/.claude/settings.json`, extract the `enabledPlugins` object, print each plugin with enabled/disabled status. |
| `env` or `environment` | Read `~/.claude/settings.json`, extract the `env` object, print each variable (mask values longer than 20 chars). |
| `statusline` | Print `~/.claude/statusline.sh`. |
| `permissions` | Read `~/.claude/settings.json`, extract `permissions` object, print allow/deny lists. |

### Project Context

| Argument | Action |
|----------|--------|
| `CLAUDE.md` or `claude-md` | Print the current project's `.claude/CLAUDE.md` (or root `CLAUDE.md`). |
| `global-claude-md` | Print `~/.claude/CLAUDE.md`. |
| `ports` or `port-map` | Print `~/.claude/projects/README.md`. |
| `deprecated` | Print `~/code/github/claude-config/deprecated-skills.yaml`. |

### Catch-All

| Argument | Action |
|----------|--------|
| No argument or `help` | Print this lookup table as a quick reference. |
| Unrecognized argument | Fuzzy match: search skill names, hook names, agent names, and setting keys. If a close match is found, confirm with the user. If no match, say "not found" and suggest `help`. |

---

## Gotchas

- Plugin list comes from settings.json — disabled plugins still show (check enabled flag)
- Hook count may differ from settings.json if hooks were added by skills at runtime

## Rules

- **Minimal tokens**: For `current-session`, `memory`, individual skill/hook/agent files — just Read and print. Do not summarize unless the user asks.
- **One Read call per item**: Don't chain multiple reads for a single lookup. If aggregating (e.g., `all-skills`), use parallel reads.
- **No writes**: This skill is read-only. Never modify any file.
- **Fuzzy matching**: If argument is `prompt`, match `my-prompt`. If `scout`, list `github-scout`. If `session-summary`, match the hook `session-summary.sh`.
- **Current project detection**: Use `git rev-parse --show-toplevel` to find project root for session/CLAUDE.md lookups.
- **`help` argument convention**: Every skill has a `## Quick Help` section. When ANY skill is invoked with `help` as its argument (e.g., `/my-prompt help`, `/bug-hunt help`), read only the `## Quick Help` section from that skill's SKILL.md and print it. Do NOT execute the skill's main logic. This convention applies to ALL skills — `/my-show-info` is just one way to access it.

## Quick Help

**What**: Quick, read-only lookup for your Claude Code setup — skills, hooks, agents, session, settings, plugins.
**Usage**:
- `/my-show-info my-prompt` — shows my-prompt's Quick Help
- `/my-show-info stop-hooks` — lists all Stop hooks with script previews
- `/my-show-info current-session` — prints latest session summary (raw, no LLM)
- `/my-show-info agents` — prints agents README
- `/my-show-info plugins` — lists plugins with enabled/disabled status
- `/my-show-info settings` — prints settings.json
- `/my-show-info help` — shows this reference
**Also works**: `/my-prompt help`, `/bug-hunt help` — any skill with `help` shows its Quick Help section.
