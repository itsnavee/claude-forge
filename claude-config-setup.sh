#!/bin/bash
# ============================================================================
# Claude Code Config — First-time Setup
# Idempotent: only installs files that don't already exist on the host.
# Safe to run multiple times — never overwrites existing config.
# Usage: ./claude-config-setup.sh
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

echo "Claude Code config setup → $CLAUDE_DIR"
echo ""

installed=0
skipped=0

# Helper: copy file only if target does not exist
install_if_missing() {
  local src="$1" dst="$2" label="$3"
  if [ -f "$dst" ]; then
    echo "  skip  $label (already exists)"
    skipped=$((skipped + 1))
  else
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    echo "  new   $label"
    installed=$((installed + 1))
  fi
}

# Helper: copy file only if missing, then chmod +x
install_script_if_missing() {
  local src="$1" dst="$2" label="$3"
  if [ -f "$dst" ]; then
    echo "  skip  $label (already exists)"
    skipped=$((skipped + 1))
  else
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    chmod +x "$dst"
    echo "  new   $label"
    installed=$((installed + 1))
  fi
}

# --- RTK (token compression for Claude Code) ---
if command -v rtk &>/dev/null; then
  echo "  skip  rtk $(rtk --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1) (already installed)"
  skipped=$((skipped + 1))
else
  echo "  installing rtk..."
  if curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh 2>/dev/null; then
    echo "  new   rtk $(rtk --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
    installed=$((installed + 1))
  else
    echo "  WARN  rtk install failed — install manually: https://github.com/rtk-ai/rtk#installation"
  fi
fi

# --- Skill Dependencies (Python venv + npm tools) ---
echo ""
echo "Skill dependencies:"

# Python venv for skill scripts (Playwright, etc.)
# On Debian/Ubuntu, python3 -m venv may not include pip (needs python3-venv package).
# Use uv when available — it creates proper venvs on any system.
venv_has_pip() { [ -f "$CLAUDE_DIR/venv/bin/pip" ] || [ -f "$CLAUDE_DIR/venv/bin/pip3" ]; }

if [ -d "$CLAUDE_DIR/venv" ] && venv_has_pip; then
  echo "  skip  venv (already exists)"
  skipped=$((skipped + 1))
else
  # Remove broken venv (exists but no pip)
  [ -d "$CLAUDE_DIR/venv" ] && rm -rf "$CLAUDE_DIR/venv"
  echo "  creating venv..."
  if command -v uv &>/dev/null; then
    uv venv "$CLAUDE_DIR/venv" 2>/dev/null && echo "  new   venv (via uv)" && installed=$((installed + 1)) || echo "  WARN  venv creation failed"
  else
    python3 -m venv "$CLAUDE_DIR/venv" 2>/dev/null && echo "  new   venv" && installed=$((installed + 1)) || echo "  WARN  venv creation failed (try: sudo apt install python3-venv)"
  fi
fi

# Playwright (in venv)
if "$CLAUDE_DIR/venv/bin/python" -c "import playwright" 2>/dev/null; then
  echo "  skip  playwright (already installed)"
  skipped=$((skipped + 1))
else
  echo "  installing playwright..."
  if command -v uv &>/dev/null; then
    uv pip install --python "$CLAUDE_DIR/venv/bin/python" playwright -q 2>/dev/null && echo "  new   playwright" && installed=$((installed + 1)) || echo "  WARN  playwright install failed"
  elif venv_has_pip; then
    "$CLAUDE_DIR/venv/bin/pip" install playwright -q 2>/dev/null && echo "  new   playwright" && installed=$((installed + 1)) || echo "  WARN  playwright install failed"
  else
    echo "  WARN  playwright install failed (no pip in venv)"
  fi
fi

# QMD (semantic search — requires Node 22+)
if command -v qmd &>/dev/null; then
  echo "  skip  qmd $(qmd --version 2>/dev/null | head -1)"
  skipped=$((skipped + 1))
else
  echo "  installing qmd..."
  npm install -g @tobilu/qmd -q 2>/dev/null && echo "  new   qmd" && installed=$((installed + 1)) || echo "  WARN  qmd install failed (needs Node 22+)"
fi

echo ""

# Banned tools enforcement — reads banned-tools.yaml and uninstalls anything
# listed. Runs on every setup so new machines are brought in line.
# Uses \x1f as the field delimiter since check/uninstall values contain shell
# pipes. See claude-config-sync.sh for the same parser.
BANNED_FILE="$SCRIPT_DIR/banned-tools.yaml"
if [ -f "$BANNED_FILE" ]; then
  echo "Banned tools (uninstalling if present):"
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
      echo "  remove  $btool  — $breason"
      if bash -c "$bunins" </dev/null >/dev/null 2>&1; then
        echo "  ok      $btool uninstalled"
      else
        echo "  WARN    $btool uninstall failed — remove manually"
      fi
    else
      echo "  skip    $btool (banned — not installed)"
    fi
  done < /tmp/.banned-tools-parsed.$$
  rm -f /tmp/.banned-tools-parsed.$$
fi

echo ""

# --- Global CLAUDE.md ---
install_if_missing "$SCRIPT_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md" "CLAUDE.md"

# --- RTK.md (reference doc for Claude Code) ---
install_if_missing "$SCRIPT_DIR/RTK.md" "$CLAUDE_DIR/RTK.md" "RTK.md"

# --- Settings ---
install_if_missing "$SCRIPT_DIR/settings.json" "$CLAUDE_DIR/settings.json" "settings.json"

# --- Statusline ---
install_script_if_missing "$SCRIPT_DIR/statusline.sh" "$CLAUDE_DIR/statusline.sh" "statusline.sh"

# --- Hooks ---
for hook in "$SCRIPT_DIR"/hooks/*.sh; do
  [ ! -f "$hook" ] && continue
  name="$(basename "$hook")"
  install_script_if_missing "$hook" "$CLAUDE_DIR/hooks/$name" "hooks/$name"
done

# --- Agent personalities (recursive — supports subdirectories) ---
while IFS= read -r agent_file; do
  [ ! -f "$agent_file" ] && continue
  rel_path="${agent_file#$SCRIPT_DIR/agents/}"
  install_if_missing "$agent_file" "$CLAUDE_DIR/agents/$rel_path" "agents/$rel_path"
done < <(find "$SCRIPT_DIR/agents" -name '*.md' -type f 2>/dev/null | sort)

# --- Skills ---
for skill_dir in "$SCRIPT_DIR"/skills/*/; do
  [ ! -d "$skill_dir" ] && continue
  skill_name="$(basename "$skill_dir")"
  [ ! -f "$skill_dir/SKILL.md" ] && continue
  install_if_missing "$skill_dir/SKILL.md" "$CLAUDE_DIR/skills/$skill_name/SKILL.md" "skills/$skill_name"
done

# --- Projects index (top-level files like README.md, port map) ---
for proj_file in "$SCRIPT_DIR"/projects/*.md; do
  [ ! -f "$proj_file" ] && continue
  fname="$(basename "$proj_file")"
  install_if_missing "$proj_file" "$CLAUDE_DIR/projects/$fname" "projects/$fname"
done

# --- Project memories ---
echo ""
echo "Project memories:"
PROJECTS_BASE="$HOME/code/github"
for proj_path in "$PROJECTS_BASE"/*/; do
  [ ! -d "$proj_path/.git" ] && continue
  proj_name="$(basename "$proj_path")"
  repo_mem_dir="$SCRIPT_DIR/projects/$proj_name/memory"
  [ ! -d "$repo_mem_dir" ] && continue  # no memories in repo for this project

  # Claude's path-encoded project directory
  claude_proj_dir="$CLAUDE_DIR/projects/-$(echo "${HOME#/}/code/github/${proj_name}" | sed 's|/|-|g')"
  mkdir -p "$claude_proj_dir/memory"

  for mem_file in "$repo_mem_dir"/*; do
    [ ! -f "$mem_file" ] && continue
    [ "$(basename "$mem_file")" = ".gitkeep" ] && continue
    fname="$(basename "$mem_file")"
    install_if_missing "$mem_file" "$claude_proj_dir/memory/$fname" "projects/$proj_name/$fname"
  done
done

echo ""
echo "Done. Installed: $installed, Skipped: $skipped"
echo "To update existing files, use: ./claude-config-sync.sh"
echo "Plugins are managed via the marketplace — enable them with /plugins in Claude."
