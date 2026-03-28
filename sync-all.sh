#!/bin/bash
# ============================================================================
# Sync All — Git update all active projects + claude-config sync + push
#
# Phase 1: For each project → stage, commit, pull --rebase, push
# Phase 2: Run claude-config bidirectional sync (settings/skills/hooks/memory)
# Phase 3: Git update the claude-config repo itself
#
# Usage: ./sync-all.sh [optional commit message]
# ============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="$HOME/code/github"
CONFIG_REPO="$SCRIPT_DIR"

# GitHub username — used to detect repo ownership (only push to repos we own)
GITHUB_USER="youruser"

# Auto-discover git repos in BASE (top-level only, excluding claude-config itself)
PROJECTS=()
for dir in "$BASE"/*/; do
  name="$(basename "$dir")"
  if [ -d "$dir/.git" ] && [ "$name" != "claude-config" ]; then
    PROJECTS+=("$name")
  fi
done

# Counters
updated=0
clean=0
failed=0
failures=""

# Commit message — use argument or default
MSG="${1:-sync: auto-update $(date +%Y-%m-%d)}"

# ── Helper: git update a single repo ────────────────────────────────────────
git_update() {
  local repo="$1"
  local name="$(basename "$repo")"

  if [ ! -d "$repo/.git" ]; then
    echo "  SKIP  $name — not a git repo"
    failed=$((failed + 1))
    failures="$failures $name"
    return 1
  fi

  cd "$repo" || return 1

  local branch
  branch="$(git branch --show-current 2>/dev/null)"
  if [ -z "$branch" ]; then
    echo "  SKIP  $name — detached HEAD"
    failed=$((failed + 1))
    failures="$failures $name"
    return 1
  fi

  # Check for changes (tracked modifications + untracked files)
  local has_changes=false
  if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
    has_changes=true
  fi
  if [ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ]; then
    has_changes=true
  fi

  if [ "$has_changes" = true ]; then
    git add -A

    git commit -m "$(cat <<EOF
$MSG

Co-Authored-By: naveed.ahmed <5332157+you@example.com>
Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)" 2>/dev/null

    if [ $? -ne 0 ]; then
      echo "  FAIL  $name — commit failed"
      failed=$((failed + 1))
      failures="$failures $name"
      return 1
    fi
  fi

  # Detect ownership: check if remote URL contains our GitHub username
  local owned=false
  local remote_url
  remote_url="$(git remote get-url origin 2>/dev/null)"
  if [[ "$remote_url" == *"$GITHUB_USER"* ]]; then
    owned=true
  fi

  # Pull rebase (may have remote changes even if local was clean)
  if git remote get-url origin &>/dev/null; then
    git pull --rebase origin "$branch" 2>/dev/null
    if [ $? -ne 0 ]; then
      echo "  FAIL  $name — rebase conflict (resolve manually)"
      git rebase --abort 2>/dev/null
      failed=$((failed + 1))
      failures="$failures $name"
      return 1
    fi

    if [ "$owned" = true ]; then
      git push origin "$branch" 2>/dev/null
      if [ $? -ne 0 ]; then
        echo "  FAIL  $name — push failed"
        failed=$((failed + 1))
        failures="$failures $name"
        return 1
      fi
    fi
  fi

  if [ "$has_changes" = true ]; then
    if [ "$owned" = true ]; then
      echo "  OK    $name [$branch] — committed and pushed"
    else
      echo "  OK    $name [$branch] — committed locally (not our repo, skipped push)"
    fi
    updated=$((updated + 1))
  else
    if [ "$owned" = true ]; then
      echo "  OK    $name [$branch] — clean (pulled latest)"
    else
      echo "  OK    $name [$branch] — clean (pulled latest, not our repo)"
    fi
    clean=$((clean + 1))
  fi
}

# ── Phase 1: Update all projects ────────────────────────────────────────────
echo "Phase 1: Git update all projects"
echo "─────────────────────────────────"
for project in "${PROJECTS[@]}"; do
  git_update "$BASE/$project"
done

# ── Phase 2: Claude-config bidirectional sync ────────────────────────────────
echo ""
echo "Phase 2: Claude-config sync (settings/skills/hooks/memory)"
echo "─────────────────────────────────"
if [ -x "$CONFIG_REPO/claude-config-sync.sh" ]; then
  bash "$CONFIG_REPO/claude-config-sync.sh"
else
  echo "  ERROR: claude-config-sync.sh not found or not executable"
fi

# ── Phase 3: Update claude-config repo ───────────────────────────────────────
echo ""
echo "Phase 3: Git update claude-config"
echo "─────────────────────────────────"
git_update "$CONFIG_REPO"

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════"
echo "  Updated: $updated  Clean: $clean  Failed: $failed"
if [ -n "$failures" ]; then
  echo "  Failures:$failures"
fi
echo "═══════════════════════════════════"
