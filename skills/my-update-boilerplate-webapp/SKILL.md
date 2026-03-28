---
name: my-update-boilerplate-webapp
description: Use when you've improved components in a project that should be upstream in boilerplate-webapp — syncs components, theme, layout, or infra changes back to the template repo. Also use for "update boilerplate", "sync to template", or "push to boilerplate".
argument-hint: "< profile | file-path > [--smart]"
allowed-tools: Bash(bash:*), Bash(git:*), Read, Write, Edit, Glob, Grep
---

# Update Boilerplate Webapp

Push improvements from the current project (my-project-2, my-project-5, etc.) back to the shared `boilerplate-webapp` repo. Uses a helper script for mechanical copying and AI intelligence for complex genericization.

## Config & Script Locations

- **Config**: `~/code/github/claude-config/boilerplate-sync-config.json`
- **Script**: `~/code/github/claude-config/update-boilerplate.sh`
- **Boilerplate**: `~/code/github/boilerplate-webapp`

## Step 1 — Detect Source Project

Determine which project we're in from CWD:

```bash
basename "$(git -C "$(pwd)" rev-parse --show-toplevel 2>/dev/null)"
```

Match against known projects in the config JSON. If CWD doesn't match any project, abort with a clear message.

## Step 2 — Determine What to Sync

Based on the arguments passed to the skill:

### No arguments (interactive/auto mode)

Run the helper script's `--changed` mode to find tracked files that were recently modified:

```bash
bash ~/code/github/claude-config/update-boilerplate.sh <project> --changed --dry-run
```

This checks `git diff` against the tracked file manifest and shows which tracked files have changes. Present the list to the user and let them confirm which files to sync.

If no recently changed tracked files are found, tell the user and suggest they can:
- Specify a file: `/update-boilerplate-webapp src/components/ui/card.tsx`
- Specify a profile: `/update-boilerplate-webapp theme`

### Profile argument (e.g., `ui`, `theme`, `layout`, `lib`, `styles`, `infra`)

Available profiles are defined in the config. List of current profiles:

| Profile | Description |
|---------|------------|
| `ui` | UI components (card, badge, tabs, table, etc.) |
| `layout` | Layout components (sidebar, top-nav, org-switcher, etc.) |
| `theme` | Theme files (globals.css, components.css, theme-context) |
| `lib` | Library utilities (theme-context, page-header-context) |
| `styles` | Console stylesheets (base, layout, components, status) |
| `infra` | Infrastructure (Dockerfiles, docker-compose, configs) |

### File path argument

A specific relative path like `src/components/ui/card.tsx`. Determine which app it belongs to by checking if the path starts with an app prefix or by inspecting the project's `app_map`.

### `--smart` flag

When present, use Mode C (AI-assisted genericization) instead of simple sed replacement. See Step 4.

## Step 3 — For Each File: Diff and Choose Sync Mode

For each file to sync:

1. **Read both files** — the source (in current project) and the target (in boilerplate). Use the project's `app_map` to resolve the correct source directory.

2. **Show a summary diff** — briefly describe what changed (don't dump the full diff into context unless the file is small). Focus on: what was added, what was modified, any project-specific content.

3. **Choose the sync mode:**

   - **Mode A — Direct copy**: The file has NO project-specific content (no brand names, no project-specific API calls, no business logic). Just copy it.
     ```bash
     bash ~/code/github/claude-config/update-boilerplate.sh <project> <app> <path>
     ```

   - **Mode B — Sed genericization**: The file has ONLY simple brand-string differences (e.g., `my-project-2-theme` → `app-theme`, `Sawabi` → `MyApp`). The replacement list in the config handles it.
     ```bash
     bash ~/code/github/claude-config/update-boilerplate.sh <project> <app> <path> --genericize
     ```

   - **Mode C — Smart genericization** (when `--smart` is used, or when the file has project-specific logic that sed can't handle): Read both versions, understand what improvement was made in the source project, and port ONLY the improvement to the boilerplate version while keeping it generic. Use the Edit tool to apply changes directly to the boilerplate file. Do NOT copy project-specific API calls, business logic, or domain-specific features.

4. **Report** what was done for each file.

## Step 4 — Smart Genericization (Mode C)

When a file needs Mode C:

1. Read the source file (current project version)
2. Read the target file (boilerplate version)
3. Identify what changed/improved in the source — focus on:
   - UI improvements (styling, layout, UX)
   - Bug fixes
   - Performance improvements
   - Better error handling
   - New generic utility functions
4. Strip out anything project-specific:
   - Project-specific API calls → keep generic placeholder or remove
   - Brand names → use generic equivalents
   - Domain-specific business logic → remove or abstract
   - Project-specific imports → remove
5. Apply the improvement to the boilerplate version using the Edit tool
6. Show the user what was changed and what was stripped

## Step 5 — Offer to Commit

After all files are synced, offer to commit the changes in the boilerplate repo:

```bash
git -C ~/code/github/boilerplate-webapp status
git -C ~/code/github/boilerplate-webapp diff --stat
```

If there are changes, ask the user if they want to commit. If yes, commit with a message like:

```
sync: update <profile/files> from <project>
```

Do NOT push automatically — just commit locally.

## Gotchas

- Project-specific customizations (colors, branding) should NOT be synced upstream — only generic improvements
- Component paths may differ between projects — verify import paths after sync

## Rules

- Always show what will change BEFORE making changes (use `--dry-run` on the script, or read both files first)
- Never sync `.env` files, secrets, or credentials
- Never sync `package.json` dependencies blindly — warn the user if package.json is in the sync list
- When in doubt between Mode B and Mode C, prefer Mode C (smart) — it's safer
- If a file exists in the source but NOT in the boilerplate, ask the user before creating it
- If a file exists in the boilerplate but NOT in the source, skip it silently
- The tracked file manifest in the config is the source of truth for what files are syncable
- Keep the boilerplate generic — it should never contain project-specific brand names, API endpoints, or business logic after syncing

## Tracked Files

The config maintains a manifest of tracked files grouped by app (studio, console, infra). These are the files we monitor for changes. When running without arguments, only tracked files that have recently changed are shown.

To add a new tracked file, edit `~/code/github/claude-config/boilerplate-sync-config.json` and add the relative path to the appropriate app group in `tracked_files`.

## Adding a New Source Project

To support syncing from a new project:

1. Add a new entry in `projects` in the config JSON
2. Define its `app_map` (how its directories map to boilerplate's `apps/studio`, `apps/console`)
3. Define its `replacements` (brand strings to genericize)
4. That's it — `tracked_files` and `sync_profiles` are shared across all projects

## Quick Help

**What**: Syncs improved components/theme/layout/infra from the current project back to boilerplate-webapp.
**Usage**:
- `/my-update-boilerplate-webapp` — auto-detects changed tracked files
- `/my-update-boilerplate-webapp ui` — sync UI profile (components, pages)
- `/my-update-boilerplate-webapp src/components/Button.tsx` — sync specific file
- `/my-update-boilerplate-webapp --smart` — AI-assisted genericization (replaces brand strings)
**Source projects**: my-project-2, my-project-5 (configured in `boilerplate-sync-config.json`).
