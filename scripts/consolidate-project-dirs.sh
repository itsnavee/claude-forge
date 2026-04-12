#!/bin/bash
# ============================================================================
# consolidate-project-dirs.sh
#
# Consolidates ~/.claude/projects/ so that each git repo has exactly ONE
# project directory — the one encoded from the repo root. Subdir-based
# project dirs (created when claude is launched from inside a subfolder of
# a repo) have their memory/transcripts merged into the repo-root dir and
# are deleted.
#
# Two modes:
#   - Full scan (default): walks every project dir in ~/.claude/projects/
#   - Single dir: pass a cwd as $1 (used by the Stop hook) — consolidates
#     only the project dir that corresponds to that cwd
#
# Env vars:
#   DRY_RUN=1   print the plan, don't move/delete anything
#   VERBOSE=1   print per-file actions
#
# Rules:
#   1. /data/code/github/X twin of /code/github/X → merge data→code, rm data
#   2. /data/code/github/X where ~/code/github/X is a git repo → rename to code-variant
#   3. Any project dir whose encoded path maps to a subdir of a git repo
#      (e.g. my-project <private> = my-project <private>  my-project is a git repo)
#      → merge into the repo root's project dir, rm the subdir-based one
#   4. True orphans (no matching repo anywhere) → leave alone, print warning
# ============================================================================

set -uo pipefail
# Intentionally NOT using -e: decode failures are expected for some dirs and
# shouldn't abort the full scan.

CLAUDE_PROJECTS="$HOME/.claude/projects"
CLAUDE_ARCHIVE="$HOME/.claude/projects-archive"
GITHUB_BASE="$HOME/code/github"
# Renames config — old project name → new project name. Checked first.
RENAMES_FILE="${RENAMES_FILE:-$HOME/code/github/claude-config/project-renames.yaml}"
DRY_RUN="${DRY_RUN:-0}"
VERBOSE="${VERBOSE:-0}"
# Skip dirs with files modified in the last N seconds — likely active session
LIVE_SECONDS="${LIVE_SECONDS:-120}"

# ----------------------------------------------------------------------------
# Load project renames into an assoc array. Format: `  old: new`.
# ----------------------------------------------------------------------------
declare -A PROJECT_RENAMES=()
if [ -f "$RENAMES_FILE" ]; then
  while IFS= read -r line; do
    # Match lines like "  old: new" (indented, simple key:value under renames:)
    if [[ "$line" =~ ^[[:space:]]+([a-zA-Z0-9._-]+)[[:space:]]*:[[:space:]]*([a-zA-Z0-9._-]+)[[:space:]]*$ ]]; then
      old="${BASH_REMATCH[1]}"
      new="${BASH_REMATCH[2]}"
      # Skip the "renames:" key itself
      [ "$old" = "renames" ] && continue
      PROJECT_RENAMES["$old"]="$new"
    fi
  done < "$RENAMES_FILE"
fi

# ----------------------------------------------------------------------------
# apply_rename <project-name>  →  renamed project-name if mapped, else unchanged
# Checks exact match AND prefix match (so "my-project-worktrees-foo" → "my-project-worktrees-foo").
# ----------------------------------------------------------------------------
apply_rename() {
  local name="$1"
  # Exact match first
  if [ -n "${PROJECT_RENAMES[$name]+x}" ]; then
    echo "${PROJECT_RENAMES[$name]}"
    return 0
  fi
  # Prefix match: "my-project-something" → "my-project-something"
  local old
  for old in "${!PROJECT_RENAMES[@]}"; do
    if [[ "$name" == "$old-"* ]]; then
      local new="${PROJECT_RENAMES[$old]}"
      echo "${new}-${name#$old-}"
      return 0
    fi
  done
  echo "$name"
}

log() { printf "%s\n" "$*"; }
vlog() { [ "$VERBOSE" = "1" ] && printf "  %s\n" "$*" || true; }
act() {
  if [ "$DRY_RUN" = "1" ]; then
    printf "  DRY-RUN: %s\n" "$*"
  else
    eval "$*"
  fi
}

# ----------------------------------------------------------------------------
# encode <absolute-path>  →  claude-projects dir name (slash → dash, leading -)
# ----------------------------------------------------------------------------
encode_path() {
  local p="$1"
  echo "-${p#/}" | tr '/' '-'
}

# ----------------------------------------------------------------------------
# decode <dir-name>  →  best-guess absolute path (tries to resolve to real path)
# The encoding is lossy (`~/code/github/foo-bar` and `~/code/github/foo/bar`
# both encode to `-Users-...-github-foo-bar`). We walk from longest to shortest
# candidate and pick the first that exists on disk.
# Output: the resolved absolute path, or empty if unresolvable.
# ----------------------------------------------------------------------------
decode_dir_name() {
  local name="$1"
  # Strip leading dash, split on dashes
  local rest="${name#-}"
  # Split into parts
  IFS='-' read -r -a parts <<< "$rest"
  local n=${#parts[@]}
  # Try combining trailing parts — longest first
  # Start with the full path (all dashes → slashes), then progressively merge
  # the last two parts with a dash, until we either find a real path or run out
  # of combinations.
  local i
  for (( i = 0; i < n; i++ )); do
    # Build candidate: first (n - i) parts as path separators, last i+1 parts joined with dashes
    local path="/${parts[0]}"
    local j
    for (( j = 1; j < n - i; j++ )); do
      path="${path}/${parts[$j]}"
    done
    if [ "$i" -gt 0 ]; then
      local trailing="${parts[$((n - i))]}"
      for (( j = n - i + 1; j < n; j++ )); do
        trailing="${trailing}-${parts[$j]}"
      done
      path="${path}/${trailing}"
    fi
    if [ -d "$path" ]; then
      echo "$path"
      return 0
    fi
  done
  # Last resort: full dash-joined name (might be a top-level dir with dashes)
  local full="/$(echo "$rest" | tr '-' '/')"
  [ -d "$full" ] && { echo "$full"; return 0; }
  echo ""
  return 1
}

# ----------------------------------------------------------------------------
# find_git_root <abs-path>  →  git repo root, or empty
# Walks up until .git/ is found.
# ----------------------------------------------------------------------------
find_git_root() {
  local p="$1"
  while [ -n "$p" ] && [ "$p" != "/" ]; do
    [ -d "$p/.git" ] && { echo "$p"; return 0; }
    p="$(dirname "$p")"
  done
  echo ""
  return 1
}

# ----------------------------------------------------------------------------
# find_repo_by_encoded_name <dir-name>  →  canonical ~/code/github/<repo> if
# the encoded name corresponds (by progressively-shrinking trailing segments)
# to a git repo under ~/code/github/. Empty if no match.
#
# Handles both exact-match (e.g. "-Users-youruser-code-github-my-project")
# and subdir cases (e.g. "-Users-youruser-data-code-github-my-project-iphone-app"
# → ~/code/github/my-project).
# ----------------------------------------------------------------------------
find_repo_by_encoded_name() {
  local name="$1"
  # Strip any known prefix down to the project-name part
  local rest="${name}"
  rest="${rest#-Users-youruser-data-code-github-}"
  rest="${rest#-Users-youruser-code-github-}"
  # If the strip didn't reduce it (prefix didn't match), fall back to
  # walking up the decoded fs path via find_git_root
  if [ "$rest" = "$name" ]; then
    return 1
  fi

  # Apply project renames BEFORE repo lookup — so e.g. my-project → my-project
  # matches my-project's repo even though my-project/ doesn't exist.
  rest=$(apply_rename "$rest")

  # Try progressively shorter trailing segments
  local candidate="$rest"
  while [ -n "$candidate" ]; do
    if [ -d "$GITHUB_BASE/$candidate/.git" ]; then
      echo "$GITHUB_BASE/$candidate"
      return 0
    fi
    # Drop the last -segment
    if [[ "$candidate" != *-* ]]; then
      break
    fi
    candidate="${candidate%-*}"
  done
  return 1
}

# ----------------------------------------------------------------------------
# merge_dirs <src> <dst>
# Recursively merges src into dst:
#   - files that only exist in src: move to dst
#   - files that exist in both: keep newer mtime
#   - after merge, src is deleted
# ----------------------------------------------------------------------------
merge_dirs() {
  local src="$1" dst="$2"
  [ ! -d "$src" ] && return 0

  if [ ! -d "$dst" ]; then
    vlog "move  $(basename "$src")/ → $(basename "$dst")/ (dst missing)"
    act "mkdir -p '$(dirname "$dst")'"
    act "mv '$src' '$dst'"
    return 0
  fi

  # Walk src with bash (not find) to avoid RTK wrapper stripping -mindepth
  (
    cd "$src" 2>/dev/null || return
    find . -type f 2>/dev/null | while read -r rel; do
      rel="${rel#./}"
      local src_f="$src/$rel"
      local dst_f="$dst/$rel"
      local dst_dir
      dst_dir="$(dirname "$dst_f")"
      act "mkdir -p '$dst_dir'"
      if [ ! -f "$dst_f" ]; then
        vlog "copy  $rel"
        act "mv '$src_f' '$dst_f'"
      else
        local src_m dst_m
        src_m=$(stat -f %m "$src_f" 2>/dev/null || echo 0)
        dst_m=$(stat -f %m "$dst_f" 2>/dev/null || echo 0)
        if [ "$src_m" -gt "$dst_m" ]; then
          vlog "overwrite (newer) $rel"
          act "mv '$src_f' '$dst_f'"
        else
          vlog "skip (older) $rel"
          act "rm -f '$src_f'"
        fi
      fi
    done
  )
  # Clean up empty dirs (walk from leaves up); deletes src if fully emptied
  act "find '$src' -type d -empty -delete 2>/dev/null || true"
}

# ----------------------------------------------------------------------------
# consolidate_one <project-dir-name>
# The core routing logic. Called per project dir.
# ----------------------------------------------------------------------------
is_live() {
  # Returns 0 (true) if any file in the dir was modified within LIVE_SECONDS
  local d="$1"
  local now newest
  now=$(date +%s)
  newest=$(find "$d" -type f -print0 2>/dev/null | \
    xargs -0 stat -f "%m" 2>/dev/null | sort -rn | head -1)
  [ -z "$newest" ] && return 1
  local age=$((now - newest))
  [ "$age" -lt "$LIVE_SECONDS" ]
}

# Obvious garbage dir names that came from running claude in / or $HOME etc.
is_garbage_dir() {
  case "$1" in
    "-"|"--"|"-Users-youruser"|"-private"*|""|".") return 0 ;;
  esac
  return 1
}

# Worktree-derived dirs — never real projects, always delete.
# Matches anything with `-worktree(s)-` or `conductor-workspaces-` anywhere
# in the encoded name. Conductor worktrees are scratch test environments;
# nothing useful ever happens in them that isn't also in the source repo.
is_worktree_dir() {
  case "$1" in
    *-claude-worktrees-*|*-worktree-*|*-worktrees-*|*-conductor-workspaces-*)
      return 0 ;;
  esac
  return 1
}

consolidate_one() {
  local dir="$1"
  local full="$CLAUDE_PROJECTS/$dir"
  [ ! -d "$full" ] && return 0

  # Obvious garbage from root/home launches → delete unconditionally
  if is_garbage_dir "$dir"; then
    log "GARBAGE $dir  (root/home launch — nothing useful)"
    act "rm -rf '$full'"
    return 0
  fi

  # Worktree dirs — always delete (scratch test envs, no real work)
  if is_worktree_dir "$dir"; then
    log "WORKTREE $dir  (conductor/git worktree scratch — deleted)"
    act "rm -rf '$full'"
    return 0
  fi

  # Live session guard — don't touch dirs being actively written
  if is_live "$full"; then
    log "LIVE   $dir  (active within last ${LIVE_SECONDS}s — skipping)"
    return 0
  fi

  # First: try the name-based repo lookup (handles subdir cases even when the
  # original data path is gone — e.g. my-project-iphone-app → my-project).
  local name_repo
  name_repo=$(find_repo_by_encoded_name "$dir")
  if [ -n "$name_repo" ]; then
    local target_name
    target_name=$(encode_path "$name_repo")
    if [ "$dir" = "$target_name" ]; then
      log "KEEP  $dir  (canonical repo-root form)"
      return 0
    fi
    log "MERGE $dir → $target_name  (maps to $name_repo)"
    merge_dirs "$full" "$CLAUDE_PROJECTS/$target_name"
    return 0
  fi

  # Fallback: try to resolve the encoded name to a real filesystem path
  local resolved
  resolved=$(decode_dir_name "$dir")

  if [ -z "$resolved" ]; then
    log "ARCHIVE $dir  (cannot resolve to any path or repo → archived)"
    act "mkdir -p '$CLAUDE_ARCHIVE'"
    act "mv '$full' '$CLAUDE_ARCHIVE/$dir'"
    return 0
  fi

  # Is the resolved path itself a git repo root?
  if [ -d "$resolved/.git" ]; then
    # It's a repo root. The correct encoded form is based on its CANONICAL
    # path (~/code/github/X). If the current dir already matches that, keep.
    # If it's a /data/ variant, rename to the /code/ variant.
    local canonical="$resolved"
    if [[ "$resolved" == "$HOME/data/code/github/"* ]]; then
      canonical="${resolved/#$HOME\/data\/code\/github\//$HOME/code/github/}"
      [ ! -d "$canonical" ] && canonical="$resolved"  # fall back if canonical doesn't exist
    fi
    local target_name
    target_name=$(encode_path "$canonical")

    if [ "$dir" = "$target_name" ]; then
      log "KEEP  $dir  (git repo root, canonical form)"
      return 0
    fi

    local target="$CLAUDE_PROJECTS/$target_name"
    log "MERGE $dir → $target_name  (repo root, non-canonical path)"
    merge_dirs "$full" "$target"
    return 0
  fi

  # Not a repo root. Walk up to find one.
  local repo_root
  repo_root=$(find_git_root "$resolved")

  if [ -z "$repo_root" ]; then
    log "ARCHIVE $dir  (resolved to $resolved — no git repo up the tree → archived)"
    act "mkdir -p '$CLAUDE_ARCHIVE'"
    act "mv '$full' '$CLAUDE_ARCHIVE/$dir'"
    return 0
  fi

  # Canonicalize repo_root to ~/code/github/ form if it's under /data/
  local canonical_repo="$repo_root"
  if [[ "$repo_root" == "$HOME/data/code/github/"* ]]; then
    local code_variant="${repo_root/#$HOME\/data\/code\/github\//$HOME/code/github/}"
    [ -d "$code_variant/.git" ] && canonical_repo="$code_variant"
  fi

  local target_name
  target_name=$(encode_path "$canonical_repo")

  if [ "$dir" = "$target_name" ]; then
    log "KEEP  $dir  (already matches canonical repo-root form)"
    return 0
  fi

  local target="$CLAUDE_PROJECTS/$target_name"
  log "MERGE $dir → $target_name  (subdir of $canonical_repo)"
  merge_dirs "$full" "$target"
}

# ----------------------------------------------------------------------------
# Main — full scan or single dir
# ----------------------------------------------------------------------------
main() {
  if [ "$DRY_RUN" = "1" ]; then
    log "== DRY RUN — no changes will be made =="
  fi

  if [ -n "${1-}" ]; then
    # Single-dir mode — argument is a cwd
    local cwd="$1"
    local name
    name=$(encode_path "$cwd")
    log "Single mode: cwd=$cwd → dir=$name"
    consolidate_one "$name" || log "  (error consolidating $name)"
  else
    # Full scan
    cd "$CLAUDE_PROJECTS" || { log "cannot cd to $CLAUDE_PROJECTS"; exit 1; }
    for d in */; do
      consolidate_one "${d%/}" || log "  (error consolidating ${d%/})"
    done
  fi
}

main "$@"
