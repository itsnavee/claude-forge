#!/bin/bash
# ============================================================================
# Claude Code Config — Bidirectional Sync
# Compares repo ↔ host by modification time. Newer file wins.
# Also discovers new hooks/skills/projects from either side.
# Usage: ./claude-config-sync.sh
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
PROJECTS_BASE="$HOME/code/github"

to_host=0
to_repo=0
skipped=0
discovered=0
purged=0

# Colors (disabled when not writing to a terminal)
if [ -t 1 ]; then
  BOLD='\033[1m'; DIM='\033[2m'
  GREEN='\033[32m'; YELLOW='\033[33m'; CYAN='\033[36m'; RED='\033[31m'
  RESET='\033[0m'
else
  BOLD=''; DIM=''; GREEN=''; YELLOW=''; CYAN=''; RED=''; RESET=''
fi

# Helper: print a section header
section() { printf "\n${BOLD}%s${RESET}\n" "$1"; }

# Helper: get file mtime as epoch seconds (portable across linux/mac)
mtime() {
  stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0
}

# Helper: sync a single file between two paths — newer wins
sync_file() {
  local repo_file="$1" host_file="$2" label="$3"

  if [ -f "$repo_file" ] && [ -f "$host_file" ]; then
    # Both exist — compare content first, then mtime
    if cmp -s "$repo_file" "$host_file"; then
      printf "  ${DIM}%-7s${RESET}  %s\n" "skip" "$label"
      skipped=$((skipped + 1))
    else
      local repo_mt host_mt
      repo_mt=$(mtime "$repo_file")
      host_mt=$(mtime "$host_file")
      if [ "$repo_mt" -gt "$host_mt" ]; then
        cp "$repo_file" "$host_file"
        printf "  ${GREEN}%-7s${RESET}  %s\n" "deploy" "$label"
        to_host=$((to_host + 1))
      else
        cp "$host_file" "$repo_file"
        printf "  ${YELLOW}%-7s${RESET}  %s\n" "pull" "$label"
        to_repo=$((to_repo + 1))
      fi
    fi
  elif [ -f "$repo_file" ]; then
    # Only in repo — deploy to host
    mkdir -p "$(dirname "$host_file")"
    cp "$repo_file" "$host_file"
    printf "  ${GREEN}%-7s${RESET}  %s  (new)\n" "deploy" "$label"
    to_host=$((to_host + 1))
  elif [ -f "$host_file" ]; then
    # Only on host — pull to repo
    mkdir -p "$(dirname "$repo_file")"
    cp "$host_file" "$repo_file"
    printf "  ${YELLOW}%-7s${RESET}  %s  (new)\n" "pull" "$label"
    to_repo=$((to_repo + 1))
  fi
}

# Helper: sync a script file (same as sync_file but ensures +x on host copy)
sync_script() {
  local repo_file="$1" host_file="$2" label="$3"
  sync_file "$repo_file" "$host_file" "$label"
  [ -f "$host_file" ] && chmod +x "$host_file"
}

# Helper: convert project name to Claude's path-encoded dir
claude_proj_path() {
  echo "$CLAUDE_DIR/projects/-$(echo "${HOME#/}/code/github/$1" | sed 's|/|-|g')"
}

printf "${BOLD}Claude Config Sync${RESET}\n"
printf "  repo  %s\n" "$SCRIPT_DIR"
printf "  host  %s\n" "$CLAUDE_DIR"

# --- Global CLAUDE.md ---
section "Global CLAUDE.md"
sync_file "$SCRIPT_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md" "CLAUDE.md"
sync_file "$SCRIPT_DIR/RTK.md" "$CLAUDE_DIR/RTK.md" "RTK.md"

# --- Agent personalities (recursive — supports subdirectories) ---
section "Agent Personalities"

# Purge deprecated agents (old flat files replaced by subdirectory structure)
DEPRECATED_AGENTS_FILE="$SCRIPT_DIR/deprecated-agents.yaml"
deprecated_agents=""
if [ -f "$DEPRECATED_AGENTS_FILE" ]; then
  while IFS= read -r line; do
    agent=$(echo "$line" | sed 's/^[[:space:]]*-[[:space:]]*//' | sed 's/[[:space:]]*#.*//' | tr -d '[:space:]')
    [ -z "$agent" ] && continue
    deprecated_agents="$deprecated_agents $agent"
    removed=false
    if [ -f "$CLAUDE_DIR/agents/$agent" ]; then
      rm -f "$CLAUDE_DIR/agents/$agent"
      removed=true
    fi
    if [ -f "$SCRIPT_DIR/agents/$agent" ]; then
      rm -f "$SCRIPT_DIR/agents/$agent"
      removed=true
    fi
    if [ "$removed" = true ]; then
      printf "  ${RED}%-7s${RESET}  %s\n" "purge" "agents/$agent"
      purged=$((purged + 1))
    fi
  done < <(grep '^[[:space:]]*-' "$DEPRECATED_AGENTS_FILE")
fi

# Helper: returns 0 if agent rel path is in the deprecated list
is_deprecated_agent() {
  local a="$1" d
  for d in $deprecated_agents; do [ "$a" = "$d" ] && return 0; done
  return 1
}

# Sync all non-deprecated agent files recursively
agent_paths=""
for f in $(find "$SCRIPT_DIR/agents" -name '*.md' -type f 2>/dev/null); do
  agent_paths="$agent_paths ${f#$SCRIPT_DIR/agents/}"
done
for f in $(find "$CLAUDE_DIR/agents" -name '*.md' -type f 2>/dev/null); do
  agent_paths="$agent_paths ${f#$CLAUDE_DIR/agents/}"
done
for rel_path in $(echo "$agent_paths" | tr ' ' '\n' | sort -u); do
  [ -z "$rel_path" ] && continue
  is_deprecated_agent "$rel_path" && continue
  mkdir -p "$(dirname "$SCRIPT_DIR/agents/$rel_path")" "$(dirname "$CLAUDE_DIR/agents/$rel_path")"
  sync_file "$SCRIPT_DIR/agents/$rel_path" "$CLAUDE_DIR/agents/$rel_path" "agents/$rel_path"
done

# --- Settings ---
section "Settings"
sync_file "$SCRIPT_DIR/settings.json" "$CLAUDE_DIR/settings.json" "settings.json"

# --- Statusline ---
section "Statusline"
sync_script "$SCRIPT_DIR/statusline.sh" "$CLAUDE_DIR/statusline.sh" "statusline.sh"
sync_script "$SCRIPT_DIR/statusline-mini.sh" "$CLAUDE_DIR/statusline-mini.sh" "statusline-mini.sh"

# --- Hooks ---
section "Hooks"
# Collect all hook names from both sides (deduplicated)
hook_names=""
for f in "$SCRIPT_DIR"/hooks/*.sh "$CLAUDE_DIR"/hooks/*.sh; do
  [ ! -f "$f" ] && continue
  hook_names="$hook_names $(basename "$f")"
done
for name in $(echo "$hook_names" | tr ' ' '\n' | sort -u); do
  [ -z "$name" ] && continue
  sync_script "$SCRIPT_DIR/hooks/$name" "$CLAUDE_DIR/hooks/$name" "$name"
done

# --- Skills ---
section "Skills"

# Read deprecated-skills.yaml: purge listed skills from both sides and build
# an exclusion list so the sync loop below never re-installs them.
# Note: uses [[:space:]] not \s for portability with macOS BSD sed.
DEPRECATED_FILE="$SCRIPT_DIR/deprecated-skills.yaml"
deprecated_skills=""
if [ -f "$DEPRECATED_FILE" ]; then
  while IFS= read -r line; do
    skill=$(echo "$line" | sed 's/^[[:space:]]*-[[:space:]]*//' | sed 's/[[:space:]]*#.*//' | tr -d '[:space:]')
    [ -z "$skill" ] && continue
    deprecated_skills="$deprecated_skills $skill"
    removed=false
    if [ -d "$CLAUDE_DIR/skills/$skill" ]; then
      rm -rf "$CLAUDE_DIR/skills/$skill"
      removed=true
    fi
    if [ -d "$SCRIPT_DIR/skills/$skill" ]; then
      rm -rf "$SCRIPT_DIR/skills/$skill"
      removed=true
    fi
    if [ "$removed" = true ]; then
      printf "  ${RED}%-7s${RESET}  %s\n" "purge" "$skill"
      purged=$((purged + 1))
    fi
  done < <(grep '^[[:space:]]*-' "$DEPRECATED_FILE")
fi

# Helper: returns 0 if skill name is in the deprecated list
is_deprecated() {
  local s="$1" d
  for d in $deprecated_skills; do [ "$s" = "$d" ] && return 0; done
  return 1
}

# Helper: find the skill definition file in a skill directory.
# Handles both skill.md and SKILL.md (case-insensitive match).
# Returns the filename (not full path) or empty string if not found.
skill_file_in() {
  local dir="$1"
  if [ -f "$dir/skill.md" ]; then echo "skill.md"
  elif [ -f "$dir/SKILL.md" ]; then echo "SKILL.md"
  else echo ""
  fi
}

# Rename detection: if a repo skill folder has no matching host folder,
# but its skill file content (excluding the 'name:' line) matches a host skill
# folder that has no matching repo folder — treat it as a rename.
# Delete the old host folder so the new name syncs cleanly.
for repo_skill_dir in "$SCRIPT_DIR"/skills/*/; do
  [ ! -d "$repo_skill_dir" ] && continue
  repo_folder="$(basename "$repo_skill_dir")"
  repo_sf="$(skill_file_in "$repo_skill_dir")"
  [ -z "$repo_sf" ] && continue
  [ -d "$CLAUDE_DIR/skills/$repo_folder" ] && continue  # folder exists on host, no rename
  is_deprecated "$repo_folder" && continue               # skip deprecated

  repo_content=$(grep -v "^name:" "$repo_skill_dir/$repo_sf")

  for host_skill_dir in "$CLAUDE_DIR"/skills/*/; do
    [ ! -d "$host_skill_dir" ] && continue
    host_folder="$(basename "$host_skill_dir")"
    host_sf="$(skill_file_in "$host_skill_dir")"
    [ -z "$host_sf" ] && continue
    [ -d "$SCRIPT_DIR/skills/$host_folder" ] && continue  # already in repo, not a rename candidate
    is_deprecated "$host_folder" && continue               # skip deprecated

    host_content=$(grep -v "^name:" "$host_skill_dir/$host_sf")

    if [ "$repo_content" = "$host_content" ]; then
      printf "  ${CYAN}%-7s${RESET}  %s → %s\n" "rename" "$host_folder" "$repo_folder"
      rm -rf "$CLAUDE_DIR/skills/$host_folder"
      to_host=$((to_host + 1))
      break
    fi
  done
done

# Sync skills — detect actual skill filename on each side (skill.md or SKILL.md)
skill_names=""
for d in "$SCRIPT_DIR"/skills/*/ "$CLAUDE_DIR"/skills/*/; do
  [ ! -d "$d" ] && continue
  skill="$(basename "$d")"
  sf="$(skill_file_in "$d")"
  [ -z "$sf" ] && continue
  is_deprecated "$skill" && continue  # never sync deprecated skills
  skill_names="$skill_names $skill"
done
for skill in $(echo "$skill_names" | tr ' ' '\n' | sort -u); do
  [ -z "$skill" ] && continue
  mkdir -p "$SCRIPT_DIR/skills/$skill" "$CLAUDE_DIR/skills/$skill"

  # Determine which filename each side uses
  repo_sf="$(skill_file_in "$SCRIPT_DIR/skills/$skill")"
  host_sf="$(skill_file_in "$CLAUDE_DIR/skills/$skill")"

  # If both exist with different cases, standardize to host's naming
  if [ -n "$repo_sf" ] && [ -n "$host_sf" ] && [ "$repo_sf" != "$host_sf" ]; then
    # Rename repo file to match host convention
    mv "$SCRIPT_DIR/skills/$skill/$repo_sf" "$SCRIPT_DIR/skills/$skill/$host_sf" 2>/dev/null || true
    repo_sf="$host_sf"
  fi

  # Use whichever filename exists (prefer host's name)
  actual_sf="${host_sf:-$repo_sf}"
  sync_file "$SCRIPT_DIR/skills/$skill/$actual_sf" "$CLAUDE_DIR/skills/$skill/$actual_sf" "$skill"
done

# --- Learning (cross-session learnings — append-merge, never overwrite) ---
section "Learning"

# Helper: merge two learning files by combining unique ### entries from both.
# Learning files are append-only logs — "newer wins" would lose entries from the
# other machine. Instead, we take the richer header and merge all unique entries.
merge_learning() {
  local repo_file="$1" host_file="$2" label="$3"

  if [ -f "$repo_file" ] && [ -f "$host_file" ]; then
    if cmp -s "$repo_file" "$host_file"; then
      printf "  ${DIM}%-7s${RESET}  %s\n" "skip" "$label"
      skipped=$((skipped + 1))
      return
    fi

    # Extract header (everything before first ### line) from both files
    local repo_header host_header
    repo_header=$(sed -n '/^### /q;p' "$repo_file")
    host_header=$(sed -n '/^### /q;p' "$host_file")

    # Use the longer header (more descriptive)
    local header
    if [ ${#host_header} -ge ${#repo_header} ]; then
      header="$host_header"
    else
      header="$repo_header"
    fi

    # Extract ### entries as blocks (awk splits on ### lines)
    # Each entry is "### date — hash — ...\n**lines...\n\n"
    local tmp_merged
    tmp_merged=$(mktemp)

    # Write header
    printf '%s\n' "$header" > "$tmp_merged"

    # Extract only ### entries (everything from first ### onward) from each file,
    # concatenate, then deduplicate by ### heading line.
    {
      sed -n '/^### /,$p' "$host_file"
      echo ""
      sed -n '/^### /,$p' "$repo_file"
    } | awk '
      /^### / { if (key && !(key in seen)) { seen[key]=1; entries[++n]=block }; key=$0; block="\n" key "\n"; next }
      key && /^$/ { block=block "\n"; next }
      key { block=block $0 "\n"; next }
      END { if (key && !(key in seen)) { seen[key]=1; entries[++n]=block }; for (i=1; i<=n; i++) printf "%s", entries[i] }
    ' >> "$tmp_merged"

    # Deploy merged result to both sides
    cp "$tmp_merged" "$repo_file"
    cp "$tmp_merged" "$host_file"
    rm -f "$tmp_merged"

    printf "  ${CYAN}%-7s${RESET}  %s\n" "merge" "$label"
    to_host=$((to_host + 1))
    to_repo=$((to_repo + 1))
  elif [ -f "$repo_file" ]; then
    mkdir -p "$(dirname "$host_file")"
    cp "$repo_file" "$host_file"
    printf "  ${GREEN}%-7s${RESET}  %s  (new)\n" "deploy" "$label"
    to_host=$((to_host + 1))
  elif [ -f "$host_file" ]; then
    mkdir -p "$(dirname "$repo_file")"
    cp "$host_file" "$repo_file"
    printf "  ${YELLOW}%-7s${RESET}  %s  (new)\n" "pull" "$label"
    to_repo=$((to_repo + 1))
  fi
}

learn_names=""
for f in "$SCRIPT_DIR"/learning/*.md "$CLAUDE_DIR"/learning/*.md; do
  [ ! -f "$f" ] && continue
  learn_names="$learn_names $(basename "$f")"
done
for fname in $(echo "$learn_names" | tr ' ' '\n' | sort -u); do
  [ -z "$fname" ] && continue
  mkdir -p "$SCRIPT_DIR/learning" "$CLAUDE_DIR/learning"
  merge_learning "$SCRIPT_DIR/learning/$fname" "$CLAUDE_DIR/learning/$fname" "learning/$fname"
done

# --- Context (setup docs, environment notes) ---
section "Context"
ctx_names=""
for f in "$SCRIPT_DIR"/context/*.md "$CLAUDE_DIR"/context/*.md; do
  [ ! -f "$f" ] && continue
  ctx_names="$ctx_names $(basename "$f")"
done
for fname in $(echo "$ctx_names" | tr ' ' '\n' | sort -u); do
  [ -z "$fname" ] && continue
  mkdir -p "$SCRIPT_DIR/context" "$CLAUDE_DIR/context"
  sync_file "$SCRIPT_DIR/context/$fname" "$CLAUDE_DIR/context/$fname" "context/$fname"
done

# --- Standalone files (quotes, etc.) ---
section "Extras"
sync_file "$SCRIPT_DIR/quotes.json" "$CLAUDE_DIR/quotes.json" "quotes.json"

# --- Projects index (top-level files like README.md, port map) ---
section "Projects Index"
proj_index_names=""
for f in "$SCRIPT_DIR"/projects/*.md "$CLAUDE_DIR"/projects/*.md; do
  [ ! -f "$f" ] && continue
  proj_index_names="$proj_index_names $(basename "$f")"
done
for fname in $(echo "$proj_index_names" | tr ' ' '\n' | sort -u); do
  [ -z "$fname" ] && continue
  mkdir -p "$SCRIPT_DIR/projects" "$CLAUDE_DIR/projects"
  sync_file "$SCRIPT_DIR/projects/$fname" "$CLAUDE_DIR/projects/$fname" "projects/$fname"
done

# --- Project memories ---
section "Project Memories"

# Collect git repos present in ~/code/github/ on this machine only
project_names=""
for proj_path in "$PROJECTS_BASE"/*/; do
  [ ! -d "$proj_path/.git" ] && continue
  bname="$(basename "$proj_path")"
  [[ "$bname" == backup-* ]] && continue
  project_names="$project_names $bname"
done

for proj_name in $(echo "$project_names" | tr ' ' '\n' | sort -u); do
  [ -z "$proj_name" ] && continue
  claude_dir="$(claude_proj_path "$proj_name")"
  repo_mem_dir="$SCRIPT_DIR/projects/$proj_name/memory"

  mkdir -p "$repo_mem_dir" "$claude_dir/memory"

  # Collect all memory file names from both sides (skip .gitkeep)
  mem_list=""
  for f in "$repo_mem_dir"/* "$claude_dir/memory"/*; do
    [ ! -f "$f" ] && continue
    bname="$(basename "$f")"
    [ "$bname" = ".gitkeep" ] && continue
    mem_list="$mem_list $bname"
  done
  # Deduplicate
  mem_list="$(echo "$mem_list" | tr ' ' '\n' | sort -u | xargs)"

  if [ -z "$mem_list" ]; then
    # No memories on either side — ensure .gitkeep exists in repo
    if [ ! -f "$repo_mem_dir/.gitkeep" ] && [ -z "$(ls -A "$repo_mem_dir" 2>/dev/null)" ]; then
      touch "$repo_mem_dir/.gitkeep"
      discovered=$((discovered + 1))
    fi
    printf "  ${DIM}%-7s${RESET}  %s\n" "empty" "$proj_name"
  else
    for fname in $mem_list; do
      sync_file "$repo_mem_dir/$fname" "$claude_dir/memory/$fname" "$proj_name/$fname"
    done
    # Remove .gitkeep if real content now exists
    rm -f "$repo_mem_dir/.gitkeep"
  fi
done

# --- Banned tools enforcement (runs every sync on every machine) ---
section "Banned Tools"
BANNED_FILE="$SCRIPT_DIR/banned-tools.yaml"
if [ -f "$BANNED_FILE" ]; then
  # Parse YAML with awk. IMPORTANT: we use \x1f (ASCII Unit Separator) as the
  # field delimiter instead of `|` because the check/uninstall values contain
  # shell pipes (`uv tool list | grep ...`). Using `|` as delimiter would
  # truncate commands and break everything. \x1f never appears in shell code.
  # Stdin redirection is also disabled on `eval` with `</dev/null` so the
  # uninstall command can't accidentally consume lines from the read loop.
  US=$'\x1f'
  awk -v us="$US" '
    /^[[:space:]]*-[[:space:]]*name:/ { if (name) print name us check us uninstall us reason; name=""; check=""; uninstall=""; reason="" }
    /^[[:space:]]*-[[:space:]]*name:/ { sub(/.*name:[[:space:]]*/, ""); name=$0 }
    /^[[:space:]]*check:/ { sub(/.*check:[[:space:]]*/, ""); gsub(/^"|"$/, ""); check=$0 }
    /^[[:space:]]*uninstall:/ { sub(/.*uninstall:[[:space:]]*/, ""); gsub(/^"|"$/, ""); uninstall=$0 }
    /^[[:space:]]*reason:/ { sub(/.*reason:[[:space:]]*/, ""); gsub(/^"|"$/, ""); reason=$0 }
    END { if (name) print name us check us uninstall us reason }
  ' "$BANNED_FILE" > /tmp/.banned-tools-parsed.$$
  while IFS="$US" read -r btool bcheck bunins breason; do
    [ -z "$btool" ] && continue
    if bash -c "$bcheck" </dev/null >/dev/null 2>&1; then
      printf "  ${RED}%-7s${RESET}  %s  — %s\n" "remove" "$btool" "$breason"
      if bash -c "$bunins" </dev/null >/dev/null 2>&1; then
        printf "  ${GREEN}%-7s${RESET}  %s uninstalled\n" "ok" "$btool"
      else
        printf "  ${YELLOW}%-7s${RESET}  %s uninstall failed — remove manually\n" "warn" "$btool"
      fi
      purged=$((purged + 1))
    else
      printf "  ${DIM}%-7s${RESET}  %s  (not present)\n" "ok" "$btool"
    fi
  done < /tmp/.banned-tools-parsed.$$
  rm -f /tmp/.banned-tools-parsed.$$
else
  printf "  ${DIM}%-7s${RESET}  no banned-tools.yaml\n" "skip"
fi

# --- Fix plugin hook permissions ---
section "Plugin Permissions"
plugin_fixed=0
while IFS= read -r sh_file; do
  if [ ! -x "$sh_file" ]; then
    chmod +x "$sh_file"
    printf "  ${GREEN}%-7s${RESET}  %s\n" "+x" "${sh_file#$CLAUDE_DIR/}"
    plugin_fixed=$((plugin_fixed + 1))
  fi
done < <(find "$CLAUDE_DIR/plugins" -name '*.sh' -type f 2>/dev/null)
if [ "$plugin_fixed" -eq 0 ]; then
  printf "  ${DIM}%-7s${RESET}  all plugin scripts executable\n" "ok"
fi

# Generate ROUTING.md from installed skills/agents/plugins
if [ -f "$SCRIPT_DIR/scripts/generate-routing.sh" ]; then
  bash "$SCRIPT_DIR/scripts/generate-routing.sh" 2>/dev/null
fi

printf "\n${DIM}──────────────────────────────────────────${RESET}\n"
printf "  ${GREEN}%d deployed${RESET}  ${YELLOW}%d pulled${RESET}  ${RED}%d purged${RESET}  ${DIM}%d unchanged${RESET}  %d discovered\n" \
  "$to_host" "$to_repo" "$purged" "$skipped" "$discovered"
if [ "$to_repo" -gt 0 ]; then
  printf "  ${YELLOW}!${RESET}  Repo changed — git diff, commit, push\n"
fi
