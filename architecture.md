# Architecture

> Structure map for claude-config repo — skills, hooks, agents, sync scripts.
> Claude reads this to know which files to touch without scanning the tree.

## Project Layout

```
claude-config/
├── skills/              # Claude Code custom skills (my-* prefix)
│   ├── my-save/         # Session summary + state.md auto-update
│   ├── my-git-sync/     # Git stage, commit, push workflow
│   ├── my-loop/         # Sequential task execution with checkpoints
│   ├── my-research-targets/  # URL research → my-project entries
│   ├── my-prompt/       # Transform rough ideas into disciplined prompts
│   ├── my-sync-all/     # Git update all projects + config sync
│   └── ...              # 20+ skills total
├── agents/              # Reusable agent personalities
│   ├── debate/          # skeptic, believer, referee (adversarial trio)
│   ├── reviewers/       # code, doc, security reviewers
│   ├── specialists/     # architect, platform, frontend
│   ├── scouts/          # github (external research)
│   └── workers/         # crawler
├── hooks/               # Claude Code event hooks (bash scripts)
│   ├── session-loader.sh     # Load previous session context on start
│   ├── session-summary.sh    # Save summary on stop
│   ├── cost-tracker.sh       # Track API costs
│   └── pre-compact-save.sh   # Save before context compaction
├── projects/            # Cross-project settings
├── prompts/             # Reusable prompt templates
├── docs/                # Planning docs
├── CLAUDE.md            # Global rules (synced to ~/.claude/CLAUDE.md)
├── settings.json        # Claude Code settings (synced to ~/.claude/settings.json)
├── statusline.sh        # Terminal statusline configuration
├── claude-config-sync.sh    # Bidirectional sync: repo ↔ ~/.claude/
├── claude-config-setup.sh   # First-time setup (idempotent)
├── sync-all.sh              # Update all git repos + run config sync
├── update-boilerplate.sh    # Sync components back to boilerplate-webapp
└── deprecated-skills.yaml   # Skills to purge during sync
```

## Sync Flow

```
claude-config repo (git)
  ↕ claude-config-sync.sh (newer-file-wins)
~/.claude/ (active config)
  ├── CLAUDE.md, settings.json
  ├── skills/my-*/
  ├── agents/
  └── hooks/ (managed by settings.json)
```

Pi Coding Agent support was removed 2026-04-12 — this repo now targets only Claude Code.

## Key Config Files

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Global rules — synced to `~/.claude/CLAUDE.md` |
| `RTK.md` | RTK token proxy documentation |
| `settings.json` | Claude Code settings (hooks, permissions, model) |
| `deprecated-skills.yaml` | Skills to remove during sync |
| `deprecated-agents.yaml` | Agents to remove during sync |

## Conventions

- Skills use `my-` prefix (e.g., `my-save`, `my-git-sync`)
- Each skill is a directory with `SKILL.md` inside
- Agents are markdown files with identity + instructions
- Hooks are bash scripts referenced in `settings.json`
- Sync scripts are bidirectional, newer-file-wins
