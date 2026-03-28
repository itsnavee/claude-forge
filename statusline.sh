#!/bin/bash
set -f

input=$(cat)

if [ -z "$input" ]; then
  printf "Claude"
  exit 0
fi

# ── Colors ─────────────────────────────────────────────
RESET="\033[0m"
DIM="\033[2m"
CYAN="\033[36m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
BOLD="\033[1m"
MAGENTA="\033[35m"
BLUE="\033[38;2;0;153;255m"
ORANGE="\033[38;2;255;176;85m"
WHITE="\033[38;2;220;220;220m"

SEP=" ${DIM}│${RESET} "
DIVIDER="${DIM}──${RESET}"

# ── Helpers ────────────────────────────────────────────
color_for_pct() {
  local pct=$1
  if [ "$pct" -ge 90 ]; then printf "$RED"
  elif [ "$pct" -ge 70 ]; then printf "$YELLOW"
  elif [ "$pct" -ge 50 ]; then printf "$ORANGE"
  else printf "$GREEN"
  fi
}

build_bar() {
  local pct=$1
  local width=$2
  [ "$pct" -lt 0 ] 2>/dev/null && pct=0
  [ "$pct" -gt 100 ] 2>/dev/null && pct=100

  local filled=$(( pct * width / 100 ))
  local empty=$(( width - filled ))
  local bar_color
  bar_color=$(color_for_pct "$pct")

  local filled_str="" empty_str=""
  for ((i=0; i<filled; i++)); do filled_str+="⛁ "; done
  for ((i=0; i<empty; i++)); do empty_str+="⛶ "; done

  printf "${bar_color}${filled_str}${DIM}${empty_str}${RESET}"
}

build_block_bar() {
  local pct=$1
  local width=$2
  [ "$pct" -lt 0 ] 2>/dev/null && pct=0
  [ "$pct" -gt 100 ] 2>/dev/null && pct=100

  local filled=$(( pct * width / 100 ))
  local empty=$(( width - filled ))
  local bar_color
  bar_color=$(color_for_pct "$pct")

  local filled_str="" empty_str=""
  for ((i=0; i<filled; i++)); do filled_str+="⛁ "; done
  for ((i=0; i<empty; i++)); do empty_str+="⛶ "; done

  printf "${bar_color}${filled_str}${DIM}${empty_str}${RESET}"
}

iso_to_epoch() {
  local iso_str="$1"

  local epoch
  epoch=$(date -d "${iso_str}" +%s 2>/dev/null)
  if [ -n "$epoch" ]; then
    echo "$epoch"
    return 0
  fi

  local stripped="${iso_str%%.*}"
  stripped="${stripped%%Z}"
  stripped="${stripped%%+*}"
  stripped="${stripped%%-[0-9][0-9]:[0-9][0-9]}"

  if [[ "$iso_str" == *"Z"* ]] || [[ "$iso_str" == *"+00:00"* ]] || [[ "$iso_str" == *"-00:00"* ]]; then
    epoch=$(env TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "$stripped" +%s 2>/dev/null)
  else
    epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$stripped" +%s 2>/dev/null)
  fi

  if [ -n "$epoch" ]; then
    echo "$epoch"
    return 0
  fi

  return 1
}

format_reset_time() {
  local iso_str="$1"
  local style="$2"
  [ -z "$iso_str" ] || [ "$iso_str" = "null" ] && return

  local epoch
  epoch=$(iso_to_epoch "$iso_str")
  [ -z "$epoch" ] && return

  local result=""
  case "$style" in
    time)
      result=$(date -j -r "$epoch" +"%l:%M%p" 2>/dev/null | sed 's/^ //; s/\.//g' | tr '[:upper:]' '[:lower:]')
      [ -z "$result" ] && result=$(date -d "@$epoch" +"%l:%M%P" 2>/dev/null | sed 's/^ //; s/\.//g')
      ;;
    datetime)
      result=$(date -j -r "$epoch" +"%b %-d, %l:%M%p" 2>/dev/null | sed 's/  / /g; s/^ //; s/\.//g' | tr '[:upper:]' '[:lower:]')
      [ -z "$result" ] && result=$(date -d "@$epoch" +"%b %-d, %l:%M%P" 2>/dev/null | sed 's/  / /g; s/^ //; s/\.//g')
      ;;
    *)
      result=$(date -j -r "$epoch" +"%b %-d" 2>/dev/null | tr '[:upper:]' '[:lower:]')
      [ -z "$result" ] && result=$(date -d "@$epoch" +"%b %-d" 2>/dev/null)
      ;;
  esac
  printf "%s" "$result"
}

# ── OAuth token resolution ─────────────────────────────
get_oauth_token() {
  local token=""

  if [ -n "$CLAUDE_CODE_OAUTH_TOKEN" ]; then
    echo "$CLAUDE_CODE_OAUTH_TOKEN"
    return 0
  fi

  if command -v security >/dev/null 2>&1; then
    local blob
    blob=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
    if [ -n "$blob" ]; then
      token=$(echo "$blob" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
      if [ -n "$token" ] && [ "$token" != "null" ]; then
        echo "$token"
        return 0
      fi
    fi
  fi

  local creds_file="${HOME}/.claude/.credentials.json"
  if [ -f "$creds_file" ]; then
    token=$(jq -r '.claudeAiOauth.accessToken // empty' "$creds_file" 2>/dev/null)
    if [ -n "$token" ] && [ "$token" != "null" ]; then
      echo "$token"
      return 0
    fi
  fi

  if command -v secret-tool >/dev/null 2>&1; then
    local blob
    blob=$(timeout 2 secret-tool lookup service "Claude Code-credentials" 2>/dev/null)
    if [ -n "$blob" ]; then
      token=$(echo "$blob" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
      if [ -n "$token" ] && [ "$token" != "null" ]; then
        echo "$token"
        return 0
      fi
    fi
  fi

  echo ""
}

# ── Data gathering ─────────────────────────────────────

# Model
MODEL=$(echo "$input" | jq -r 'if .model | type == "object" then .model.display_name // .model.id else .model // "?" end')

# Context usage
CTX_PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
CTX_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // 0')

if [ "$CTX_SIZE" -gt 0 ] 2>/dev/null; then
  CTX_USED=$(( CTX_SIZE * CTX_PCT / 100 ))
  CTX_USED_K=$(( CTX_USED / 1000 ))
  CTX_SIZE_K=$(( CTX_SIZE / 1000 ))
  CTX_DISPLAY="${CTX_USED_K}k/${CTX_SIZE_K}k"
else
  CTX_DISPLAY="?/?";
fi

# CWD
PWD_VAL=$(echo "$input" | jq -r '.cwd // .workspace.current_dir // "?"')
PWD_SHORT="$PWD_VAL"
case "$PWD_VAL" in "$HOME"*) PWD_SHORT="~${PWD_VAL#$HOME}" ;; esac
PROJECT_NAME=$(basename "$PWD_VAL")

# Session title
SESSION_TITLE=$(echo "$input" | jq -r '.session.name // empty')

# Git branch + dirty indicator
GIT_BRANCH=""
if command -v git &>/dev/null && [ -d "${PWD_VAL}/.git" ] 2>/dev/null || git -C "$PWD_VAL" rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
  GIT_BRANCH=$(git -C "$PWD_VAL" symbolic-ref --short HEAD 2>/dev/null || git -C "$PWD_VAL" describe --tags --exact-match 2>/dev/null || echo "")
  if [ -n "$GIT_BRANCH" ]; then
    if ! git -C "$PWD_VAL" diff --quiet 2>/dev/null || ! git -C "$PWD_VAL" diff --cached --quiet 2>/dev/null; then
      GIT_BRANCH="${GIT_BRANCH}*"
    fi
  fi
fi

# Session cost today
COST_TODAY=""
COSTS_FILE="$HOME/.claude/metrics/costs.jsonl"
if [ -f "$COSTS_FILE" ]; then
  TODAY=$(date +%Y-%m-%d)
  COST_TODAY=$(grep "$TODAY" "$COSTS_FILE" 2>/dev/null | awk -F'"cost_usd":' '{sum += $2} END {if (sum > 0) printf "$%.2f", sum}')
fi

# Session duration
SESSION_DURATION=""
SESSION_START=$(echo "$input" | jq -r '.session.start_time // empty')
if [ -n "$SESSION_START" ] && [ "$SESSION_START" != "null" ]; then
  START_EPOCH=$(iso_to_epoch "$SESSION_START" 2>/dev/null)
  if [ -z "$START_EPOCH" ]; then
    STRIPPED="${SESSION_START%%.*}"
    STRIPPED="${STRIPPED%%Z}"
    STRIPPED="${STRIPPED%%+*}"
    STRIPPED="${STRIPPED%%-[0-9][0-9]:[0-9][0-9]}"
    START_EPOCH=$(env TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "$STRIPPED" +%s 2>/dev/null)
    [ -z "$START_EPOCH" ] && START_EPOCH=$(date -d "${SESSION_START}" +%s 2>/dev/null)
  fi
  if [ -n "$START_EPOCH" ]; then
    NOW_EPOCH=$(date +%s)
    ELAPSED=$(( NOW_EPOCH - START_EPOCH ))
    if [ "$ELAPSED" -ge 3600 ]; then
      SESSION_DURATION="$(( ELAPSED / 3600 ))h$(( (ELAPSED % 3600) / 60 ))m"
    elif [ "$ELAPSED" -ge 60 ]; then
      SESSION_DURATION="$(( ELAPSED / 60 ))m"
    else
      SESSION_DURATION="${ELAPSED}s"
    fi
  fi
fi

# Thinking effort
EFFORT="default"
SETTINGS_PATH="$HOME/.claude/settings.json"
if [ -f "$SETTINGS_PATH" ]; then
  EFFORT=$(jq -r '.effortLevel // "default"' "$SETTINGS_PATH" 2>/dev/null)
fi

# Claude Code version
CC_VERSION=$(claude --version 2>/dev/null | head -1 | awk '{print $1}')
[ -z "$CC_VERSION" ] && CC_VERSION="?"

# Skill count (find instead of glob — set -f disables globbing)
SKILL_COUNT=$(find "$HOME/.claude/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')

# Hook count
HOOK_COUNT=0
if [ -f "$SETTINGS_PATH" ]; then
  HOOK_COUNT=$(jq '[.hooks // {} | to_entries[] | .value | length] | add // 0' "$SETTINGS_PATH" 2>/dev/null)
fi

# Agent count
AGENT_COUNT=$(find "$HOME/.claude/agents" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')

# Learning file count
LEARNING_COUNT=$(find "$HOME/.claude/learning" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')

# Session count (depth 2 = project/session.jsonl, excludes subagent transcripts)
SESSION_COUNT=$(find "$HOME/.claude/projects" -maxdepth 2 -name '*.jsonl' -type f 2>/dev/null | wc -l | tr -d ' ')

# Subagent session count
SUBAGENT_COUNT=$(find "$HOME/.claude/projects" -mindepth 3 -name 'agent-*.jsonl' -type f 2>/dev/null | wc -l | tr -d ' ')

# Cross-machine stats — write local, read all (throttled to every 5 min)
MACHINE_STATS_DIR="$HOME/code/github/claude-config/machine-stats"
MACHINE_NAME=$(hostname -s 2>/dev/null || echo "unknown")
MACHINE_STATS_FILE="$MACHINE_STATS_DIR/${MACHINE_NAME}.json"
machine_stats_max_age=300

TOTAL_SESSIONS="$SESSION_COUNT"
TOTAL_SUBAGENTS="$SUBAGENT_COUNT"

if [ -d "$MACHINE_STATS_DIR" ]; then
  # Write local stats (throttled)
  should_write=0
  if [ ! -f "$MACHINE_STATS_FILE" ]; then
    should_write=1
  else
    file_age=$(( $(date +%s) - $(stat -c %Y "$MACHINE_STATS_FILE" 2>/dev/null || stat -f %m "$MACHINE_STATS_FILE" 2>/dev/null || echo 0) ))
    [ "$file_age" -gt "$machine_stats_max_age" ] && should_write=1
  fi
  if [ "$should_write" -eq 1 ]; then
    printf '{"machine":"%s","sessions":%d,"subagents":%d,"updated":"%s"}\n' \
      "$MACHINE_NAME" "$SESSION_COUNT" "$SUBAGENT_COUNT" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      > "$MACHINE_STATS_FILE"
  fi

  # Read all machines and aggregate (re-enable globbing temporarily — set -f is active)
  set +f
  for sf in "$MACHINE_STATS_DIR"/*.json; do
    [ -f "$sf" ] || continue
    m=$(jq -r '.machine // empty' "$sf" 2>/dev/null)
    s=$(jq -r '.sessions // 0' "$sf" 2>/dev/null)
    a=$(jq -r '.subagents // 0' "$sf" 2>/dev/null)
    [ -z "$m" ] && continue
    if [ "$m" != "$MACHINE_NAME" ]; then
      TOTAL_SESSIONS=$((TOTAL_SESSIONS + s))
      TOTAL_SUBAGENTS=$((TOTAL_SUBAGENTS + a))
    fi
  done
  set -f
fi

# Random quote (cached 10 min so it doesn't change every refresh)
QUOTE_TEXT=""
QUOTE_AUTHOR=""
QUOTES_FILE="$HOME/.claude/quotes.json"
quote_cache="/tmp/claude/statusline-quote-cache.txt"
quote_max_age=600

quote_needs_refresh=true
if [ -f "$quote_cache" ]; then
  qc_mtime=$(stat -c %Y "$quote_cache" 2>/dev/null || stat -f %m "$quote_cache" 2>/dev/null)
  qc_now=$(date +%s)
  qc_age=$(( qc_now - qc_mtime ))
  if [ "$qc_age" -lt "$quote_max_age" ]; then
    quote_needs_refresh=false
    QUOTE_TEXT=$(sed -n '1p' "$quote_cache")
    QUOTE_AUTHOR=$(sed -n '2p' "$quote_cache")
  fi
fi

if $quote_needs_refresh && [ -f "$QUOTES_FILE" ]; then
  QUOTE_COUNT=$(jq 'length' "$QUOTES_FILE" 2>/dev/null)
  if [ -n "$QUOTE_COUNT" ] && [ "$QUOTE_COUNT" -gt 0 ] 2>/dev/null; then
    RAND_IDX=$(( RANDOM % QUOTE_COUNT ))
    QUOTE_TEXT=$(jq -r ".[$RAND_IDX].text" "$QUOTES_FILE" 2>/dev/null)
    QUOTE_AUTHOR=$(jq -r ".[$RAND_IDX].author" "$QUOTES_FILE" 2>/dev/null)
    printf "%s\n%s" "$QUOTE_TEXT" "$QUOTE_AUTHOR" > "$quote_cache"
  fi
fi

# Context color
if [ "$CTX_PCT" -lt 40 ] 2>/dev/null; then
  CTX_COLOR="$GREEN"
elif [ "$CTX_PCT" -lt 60 ] 2>/dev/null; then
  CTX_COLOR="$YELLOW"
else
  CTX_COLOR="$RED"
fi

# Effort indicator
EFFORT_STR=""
case "$EFFORT" in
  high)   EFFORT_STR="${MAGENTA}● high${RESET}" ;;
  medium) EFFORT_STR="${DIM}◑ medium${RESET}" ;;
  low)    EFFORT_STR="${DIM}◔ low${RESET}" ;;
  *)      EFFORT_STR="${DIM}◑ default${RESET}" ;;
esac

# ── Network info (cached 60s) ──────────────────────────
net_cache="/tmp/claude/statusline-net-cache.txt"
HOSTNAME_VAL=""
WIFI_IP=""
ETH_IP=""

net_needs_refresh=true
if [ -f "$net_cache" ]; then
  net_mtime=$(stat -c %Y "$net_cache" 2>/dev/null || stat -f %m "$net_cache" 2>/dev/null)
  net_now=$(date +%s)
  net_age=$(( net_now - net_mtime ))
  if [ "$net_age" -lt 60 ]; then
    net_needs_refresh=false
  fi
fi

if $net_needs_refresh; then
  HOSTNAME_VAL=$(hostname -s 2>/dev/null || hostname 2>/dev/null)
  if command -v ipconfig &>/dev/null; then
    WIFI_IP=$(ipconfig getifaddr en0 2>/dev/null || echo "")
    ETH_IP=$(ipconfig getifaddr en1 2>/dev/null || echo "")
    if [ -z "$ETH_IP" ]; then
      for iface in en2 en3 en4 en5; do
        ETH_IP=$(ipconfig getifaddr "$iface" 2>/dev/null || echo "")
        [ -n "$ETH_IP" ] && break
      done
    fi
  else
    WIFI_IP=$(ip -4 addr show wlan0 2>/dev/null | grep -oP 'inet \K[^/]+' || \
              ip -4 addr show wlp0s20f3 2>/dev/null | grep -oP 'inet \K[^/]+' || \
              echo "")
    ETH_IP=$(ip -4 addr show eth0 2>/dev/null | grep -oP 'inet \K[^/]+' || \
             ip -4 addr show enp0s31f6 2>/dev/null | grep -oP 'inet \K[^/]+' || \
             ip -4 addr show eno1 2>/dev/null | grep -oP 'inet \K[^/]+' || \
             echo "")
    if [ -z "$WIFI_IP" ] && [ -z "$ETH_IP" ]; then
      ETH_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    fi
  fi
  printf "%s\n%s\n%s" "$HOSTNAME_VAL" "$WIFI_IP" "$ETH_IP" > "$net_cache"
else
  HOSTNAME_VAL=$(sed -n '1p' "$net_cache")
  WIFI_IP=$(sed -n '2p' "$net_cache")
  ETH_IP=$(sed -n '3p' "$net_cache")
fi

# ── Fetch usage data (cached 60s) ─────────────────────
cache_file="/tmp/claude/statusline-usage-cache.json"
cache_max_age=60
mkdir -p /tmp/claude

needs_refresh=true
usage_data=""

if [ -f "$cache_file" ]; then
  cache_mtime=$(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null)
  now=$(date +%s)
  cache_age=$(( now - cache_mtime ))
  if [ "$cache_age" -lt "$cache_max_age" ]; then
    needs_refresh=false
    usage_data=$(cat "$cache_file" 2>/dev/null)
  fi
fi

if $needs_refresh; then
  token=$(get_oauth_token)
  if [ -n "$token" ] && [ "$token" != "null" ]; then
    response=$(curl -s --max-time 5 \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $token" \
      -H "anthropic-beta: oauth-2025-04-20" \
      -H "User-Agent: claude-code/2.1.34" \
      "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)
    if [ -n "$response" ] && echo "$response" | jq -e '.five_hour' >/dev/null 2>&1; then
      usage_data="$response"
      echo "$response" > "$cache_file"
    fi
  fi
  if [ -z "$usage_data" ] && [ -f "$cache_file" ]; then
    usage_data=$(cat "$cache_file" 2>/dev/null)
  fi
fi

# ══════════════════════════════════════════════════════
# ── OUTPUT: Nice and compact layout ─────────────────
# ══════════════════════════════════════════════════════

# ── Learning sparklines (entry count per category) ────
SPARK_CHARS=(▁ ▂ ▃ ▄ ▅ ▆ ▇ █)

count_entries() {
  local file="$1"
  [ -f "$file" ] || { echo 0; return; }
  local n
  n=$(grep -c '^### ' "$file" 2>/dev/null)
  echo "${n:-0}"
}

spark_char() {
  local val=$1 max=$2
  [ "$max" -le 0 ] && { printf "%s" "${SPARK_CHARS[0]}"; return; }
  local idx=$(( val * 7 / max ))
  [ "$idx" -gt 7 ] && idx=7
  printf "%s" "${SPARK_CHARS[$idx]}"
}

LEARN_DIR="$HOME/.claude/learning"
FAIL_N=$(count_entries "$LEARN_DIR/failures.md")
SIG_N=$(count_entries "$LEARN_DIR/signals.md")
SYS_N=$(count_entries "$LEARN_DIR/system.md")
ALGO_N=$(count_entries "$LEARN_DIR/algorithm.md")
SYN_N=$(count_entries "$LEARN_DIR/synthesis.md")

# Find max for scaling
LEARN_MAX=$FAIL_N
[ "$SIG_N" -gt "$LEARN_MAX" ] && LEARN_MAX=$SIG_N
[ "$SYS_N" -gt "$LEARN_MAX" ] && LEARN_MAX=$SYS_N
[ "$ALGO_N" -gt "$LEARN_MAX" ] && LEARN_MAX=$ALGO_N
[ "$SYN_N" -gt "$LEARN_MAX" ] && LEARN_MAX=$SYN_N
[ "$LEARN_MAX" -eq 0 ] && LEARN_MAX=1

LEARN_TOTAL=$(( FAIL_N + SIG_N + SYS_N + ALGO_N + SYN_N ))

# ── Build rate limit data ──
rate_lines=""

if [ -n "$usage_data" ] && echo "$usage_data" | jq -e . >/dev/null 2>&1; then
  bar_width=20

  five_hour_pct=$(echo "$usage_data" | jq -r '.five_hour.utilization // 0' | awk '{printf "%.0f", $1}')
  five_hour_reset_iso=$(echo "$usage_data" | jq -r '.five_hour.resets_at // empty')
  five_hour_reset=$(format_reset_time "$five_hour_reset_iso" "time")
  five_hour_bar=$(build_bar "$five_hour_pct" "$bar_width")
  five_hour_pct_color=$(color_for_pct "$five_hour_pct")
  five_hour_pct_fmt=$(printf "%3d" "$five_hour_pct")

  rate_lines+="${WHITE}current${RESET}  ${five_hour_bar}  ${five_hour_pct_color}${five_hour_pct_fmt}%${RESET}  ${DIM}⟳ ${RESET}${WHITE}${five_hour_reset}${RESET}"

  seven_day_pct=$(echo "$usage_data" | jq -r '.seven_day.utilization // 0' | awk '{printf "%.0f", $1}')
  seven_day_reset_iso=$(echo "$usage_data" | jq -r '.seven_day.resets_at // empty')
  seven_day_reset=$(format_reset_time "$seven_day_reset_iso" "datetime")
  seven_day_bar=$(build_bar "$seven_day_pct" "$bar_width")
  seven_day_pct_color=$(color_for_pct "$seven_day_pct")
  seven_day_pct_fmt=$(printf "%3d" "$seven_day_pct")

  rate_lines+="\n${WHITE}weekly ${RESET}  ${seven_day_bar}  ${seven_day_pct_color}${seven_day_pct_fmt}%${RESET}  ${DIM}⟳ ${RESET}${WHITE}${seven_day_reset}${RESET}"

  extra_enabled=$(echo "$usage_data" | jq -r '.extra_usage.is_enabled // false')
  if [ "$extra_enabled" = "true" ]; then
    extra_pct=$(echo "$usage_data" | jq -r '.extra_usage.utilization // 0' | awk '{printf "%.0f", $1}')
    extra_used=$(echo "$usage_data" | jq -r '.extra_usage.used_credits // 0' | awk '{printf "%.2f", $1/100}')
    extra_limit=$(echo "$usage_data" | jq -r '.extra_usage.monthly_limit // 0' | awk '{printf "%.2f", $1/100}')
    extra_bar=$(build_bar "$extra_pct" "$bar_width")
    extra_pct_color=$(color_for_pct "$extra_pct")

    extra_reset=$(date -v+1m -v1d +"%b %-d" 2>/dev/null | tr '[:upper:]' '[:lower:]')
    if [ -z "$extra_reset" ]; then
      extra_reset=$(date -d "$(date +%Y-%m-01) +1 month" +"%b %-d" 2>/dev/null | tr '[:upper:]' '[:lower:]')
    fi

    rate_lines+="\n${WHITE}extra  ${RESET}  ${extra_bar}  ${extra_pct_color}\$${extra_used}${DIM} / ${RESET}${WHITE}\$${extra_limit}${RESET}  ${DIM}⟳ ${RESET}${WHITE}${extra_reset}${RESET}"
  fi
fi

# ── Build sparkline string ──
F_SP=$(spark_char "$FAIL_N" "$LEARN_MAX")
S_SP=$(spark_char "$SIG_N" "$LEARN_MAX")
Y_SP=$(spark_char "$SYS_N" "$LEARN_MAX")
A_SP=$(spark_char "$ALGO_N" "$LEARN_MAX")
N_SP=$(spark_char "$SYN_N" "$LEARN_MAX")

CTX_BAR=$(build_block_bar "$CTX_PCT" 20)

# ── Weather (cached 10 min) ─────────────────────────────
loc_cache="/tmp/claude/statusline-loc-cache.txt"
loc_max_age=600
LOC_CITY=""
LOC_WEATHER=""
LOC_TEMP_NUM=""

loc_needs_refresh=true
if [ -f "$loc_cache" ]; then
  lc_mtime=$(stat -c %Y "$loc_cache" 2>/dev/null || stat -f %m "$loc_cache" 2>/dev/null)
  lc_now=$(date +%s)
  lc_age=$(( lc_now - lc_mtime ))
  if [ "$lc_age" -lt "$loc_max_age" ]; then
    loc_needs_refresh=false
    LOC_CITY=$(sed -n '1p' "$loc_cache")
    LOC_WEATHER=$(sed -n '2p' "$loc_cache")
    LOC_TEMP_NUM=$(sed -n '3p' "$loc_cache")
  fi
fi

if $loc_needs_refresh; then
  wttr=$(curl -s --max-time 3 "wttr.in/?format=%l|%C+%t" 2>/dev/null)
  if [ -n "$wttr" ] && [[ "$wttr" != *"Unknown"* ]] && [[ "$wttr" != *"Sorry"* ]]; then
    LOC_CITY="${wttr%%|*}"
    LOC_WEATHER="${wttr#*|}"
    # Extract numeric temperature
    LOC_TEMP_NUM=$(echo "$LOC_WEATHER" | grep -oP '[+-]?\d+' | head -1)
  else
    LOC_CITY="Gujranwala, Pakistan"
    LOC_WEATHER="?"
    LOC_TEMP_NUM=""
  fi
  printf "%s\n%s\n%s" "$LOC_CITY" "$LOC_WEATHER" "$LOC_TEMP_NUM" > "$loc_cache"
fi

# Temperature-based color (5 tiers)
TEMP_COLOR="$WHITE"
if [ -n "$LOC_TEMP_NUM" ] 2>/dev/null; then
  if [ "$LOC_TEMP_NUM" -le 0 ] 2>/dev/null; then
    TEMP_COLOR="\033[38;2;100;180;255m"   # icy blue — freezing
  elif [ "$LOC_TEMP_NUM" -le 15 ] 2>/dev/null; then
    TEMP_COLOR="$CYAN"                     # cool cyan
  elif [ "$LOC_TEMP_NUM" -le 25 ] 2>/dev/null; then
    TEMP_COLOR="$GREEN"                    # pleasant green
  elif [ "$LOC_TEMP_NUM" -le 35 ] 2>/dev/null; then
    TEMP_COLOR="$ORANGE"                   # warm orange
  else
    TEMP_COLOR="$RED"                      # hot red
  fi
fi

# ── Timezone clocks ────────────────────────────────────
PAK_TIME=$(TZ="Asia/Karachi" date +"%l:%M%p" | sed 's/^ //; s/\.//g' | tr '[:upper:]' '[:lower:]')
DUB_TIME=$(TZ="Europe/Dublin" date +"%l:%M%p" | sed 's/^ //; s/\.//g' | tr '[:upper:]' '[:lower:]')
NYSE_TIME=$(TZ="America/New_York" date +"%l:%M%p" | sed 's/^ //; s/\.//g' | tr '[:upper:]' '[:lower:]')

# NASDAQ market hours: Mon-Fri 9:30am-4:00pm ET
NYSE_HOUR=$(TZ="America/New_York" date +%H)
NYSE_MIN=$(TZ="America/New_York" date +%M)
NYSE_DOW=$(TZ="America/New_York" date +%u)  # 1=Mon, 7=Sun
NYSE_MINS=$(( NYSE_HOUR * 60 + NYSE_MIN ))
MARKET_OPEN=570   # 9:30am
MARKET_CLOSE=960  # 4:00pm
if [ "$NYSE_DOW" -le 5 ] && [ "$NYSE_MINS" -ge "$MARKET_OPEN" ] && [ "$NYSE_MINS" -lt "$MARKET_CLOSE" ]; then
  MARKET_TAG="${GREEN}OPEN${RESET}"
else
  # Calculate time until next open
  if [ "$NYSE_DOW" -ge 6 ]; then
    # Weekend: days until Monday morning
    days_until=$(( 8 - NYSE_DOW ))  # Sat=6→2, Sun=7→1
    mins_until=$(( (days_until - 1) * 1440 + (1440 - NYSE_MINS) + MARKET_OPEN ))
  elif [ "$NYSE_MINS" -ge "$MARKET_CLOSE" ]; then
    # After close weekday
    if [ "$NYSE_DOW" -eq 5 ]; then
      # Friday after close → Monday open
      mins_until=$(( 3 * 1440 - NYSE_MINS + MARKET_OPEN ))
    else
      mins_until=$(( 1440 - NYSE_MINS + MARKET_OPEN ))
    fi
  else
    # Before open weekday
    mins_until=$(( MARKET_OPEN - NYSE_MINS ))
  fi
  hrs_until=$(( mins_until / 60 ))
  if [ "$hrs_until" -gt 0 ]; then
    MARKET_TAG="${RED}CLOSED${RESET} ${DIM}${hrs_until}hr to open${RESET}"
  else
    MARKET_TAG="${RED}CLOSED${RESET} ${DIM}${mins_until}m to open${RESET}"
  fi
fi

# ── Render ─────────────────────────────────────────────

# Header
HEADER="${DIM}// OTUS STATUSLINE MAX //// PROJ: ${RESET}${BOLD}${CYAN}${PROJECT_NAME}${RESET}"
[ -n "$SESSION_TITLE" ] && [ "$SESSION_TITLE" != "null" ] && HEADER+=" ${DIM}${SESSION_TITLE}${RESET}"
printf "${HEADER}\n"

# ── divider ──
printf "${DIM}────────────────────────────────────────────────────────────────────────────────${RESET}\n"
# MODEL
printf "${MAGENTA}⬡${RESET} ${WHITE}MODEL:${RESET} ${CYAN}${MODEL}${RESET}${SEP}${EFFORT_STR}\n"
# CONTEXT
printf "${GREEN}⛁${RESET} ${WHITE}CONTEXT:${RESET} ${CTX_BAR}  ${CTX_COLOR}${CTX_PCT}%%${RESET}  ${DIM}${CTX_DISPLAY}${RESET}\n"

# ── divider ──
printf "${DIM}────────────────────────────────────────────────────────────────────────────────${RESET}\n"



# LOC
printf "${RED}⚐${RESET} ${WHITE}LOC:${RESET} ${DIM}${LOC_CITY}${RESET}${SEP}${WHITE}PAK:${RESET} ${CYAN}${PAK_TIME}${RESET}${DIM},${RESET} ${WHITE}DUB:${RESET} ${CYAN}${DUB_TIME}${RESET}${DIM},${RESET} ${WHITE}ET:${RESET} ${CYAN}${NYSE_TIME}${RESET} ${DIM}[${RESET}${MARKET_TAG}${DIM}]${RESET}${SEP}${TEMP_COLOR}${LOC_WEATHER}${RESET}\n"


# NET
printf "${BLUE}◇${RESET} ${WHITE}NET:${RESET} ${MAGENTA}${HOSTNAME_VAL}${RESET}${SEP}${GREEN}wifi${RESET} ${WHITE}${WIFI_IP:-<>}${RESET}${SEP}${CYAN}lan${RESET} ${WHITE}${ETH_IP:-<>}${RESET}\n"

# PWD
printf "${GREEN}◆${RESET} ${WHITE}PWD:${RESET} ${CYAN}${PWD_SHORT}${RESET}"
[ -n "$GIT_BRANCH" ] && printf "${SEP}${GREEN}${GIT_BRANCH}${RESET}"
[ -n "$SESSION_DURATION" ] && printf "${SEP}${DIM}⏱ ${RESET}${WHITE}${SESSION_DURATION}${RESET}"
printf "\n"

# QUOTE (word-wrap at 80 chars)
if [ -n "$QUOTE_TEXT" ] && [ "$QUOTE_TEXT" != "null" ]; then
  QUOTE_FULL="\"${QUOTE_TEXT}\" [ ${QUOTE_AUTHOR} ]"
  if [ "${#QUOTE_FULL}" -le 78 ]; then
    printf "${YELLOW}✎${RESET} ${WHITE}\"${QUOTE_TEXT}\"${RESET} ${DIM}[ ${QUOTE_AUTHOR} ]${RESET}\n"
  else
    WRAP_WIDTH=76
    CONT_WIDTH=78
    remaining="$QUOTE_TEXT"
    lines=()
    first=true
    while [ -n "$remaining" ]; do
      if $first; then max=$WRAP_WIDTH; else max=$CONT_WIDTH; fi
      if [ "${#remaining}" -le "$max" ]; then
        lines+=("$remaining")
        remaining=""
      else
        chunk="${remaining:0:$max}"
        last_space="${chunk% *}"
        if [ "$last_space" != "$chunk" ] && [ "${#last_space}" -gt 20 ]; then
          chunk="$last_space"
        fi
        lines+=("$chunk")
        remaining="${remaining:${#chunk}}"
        remaining="${remaining# }"
      fi
      first=false
    done
    last_idx=$(( ${#lines[@]} - 1 ))
    for idx in "${!lines[@]}"; do
      if [ "$idx" -eq 0 ]; then
        if [ "$idx" -eq "$last_idx" ]; then
          printf "${YELLOW}✎${RESET} ${WHITE}\"${lines[$idx]}\"${RESET} ${DIM}[ ${QUOTE_AUTHOR} ]${RESET}\n"
        else
          printf "${YELLOW}✎${RESET} ${WHITE}\"${lines[$idx]}${RESET}\n"
        fi
      elif [ "$idx" -eq "$last_idx" ]; then
        printf "  ${WHITE}${lines[$idx]}\"${RESET} ${DIM}[ ${QUOTE_AUTHOR} ]${RESET}\n"
      else
        printf "  ${WHITE}${lines[$idx]}${RESET}\n"
      fi
    done
  fi
fi

# ── divider ──
printf "${DIM}────────────────────────────────────────────────────────────────────────────────${RESET}\n"

# CLAUDE USAGE / RATE LIMIT
if [ -n "$rate_lines" ]; then
  printf "%b\n" "$rate_lines"
  printf "${DIM}────────────────────────────────────────────────────────────────────────────────${RESET}\n"
fi

# ENV
printf "${RED}⛯${RESET} ${WHITE}ENV:${RESET} ${BLUE}CC:${CC_VERSION}${RESET}${SEP}${WHITE}SK:${SKILL_COUNT}${RESET}${SEP}${WHITE}AG:${AGENT_COUNT}${RESET}${SEP}${WHITE}Hooks:${HOOK_COUNT}${RESET}\n"

# MEMORY
printf "${MAGENTA}◎${RESET} ${WHITE}MEMORY:${RESET} ${WHITE}${LEARNING_COUNT}${RESET}${DIM} learnings${RESET}"
[ -n "$COST_TODAY" ] && printf "${SEP}${MAGENTA}${COST_TODAY}${RESET}${DIM} today${RESET}"
printf "${SEP}${WHITE}${TOTAL_SESSIONS}${RESET}${DIM} sessions${RESET}"
if [ "$TOTAL_SUBAGENTS" -gt 0 ] 2>/dev/null; then
  printf "${SEP}${WHITE}${TOTAL_SUBAGENTS}${RESET}${DIM} subagent sessions${RESET}"
fi
printf "\n"

# LEARNING — 14-day activity sparkline graph + category counts
SPARK_LINE=""
SPARK_MAX=0
SPARK_DAYS=()
for i in 13 12 11 10 9 8 7 6 5 4 3 2 1 0; do
  d=$(date -d "-${i} days" +%Y-%m-%d 2>/dev/null)
  [ -z "$d" ] && d=$(date -v-${i}d +%Y-%m-%d 2>/dev/null)
  count=0
  if [ -n "$d" ]; then
    count=$(grep -rl "$d" "$HOME/.claude/sessions/" "$HOME/.claude/learning/" 2>/dev/null | wc -l | tr -d ' ')
  fi
  SPARK_DAYS+=("$count")
  [ "$count" -gt "$SPARK_MAX" ] && SPARK_MAX=$count
done
[ "$SPARK_MAX" -eq 0 ] && SPARK_MAX=1

for val in "${SPARK_DAYS[@]}"; do
  sc=$(spark_char "$val" "$SPARK_MAX")
  SPARK_LINE+="${sc}"
done

printf "${ORANGE}◈${RESET} ${WHITE}LEARNING:${RESET} ${CYAN}${SPARK_LINE}${RESET} ${DIM}(14d)${RESET}  ${DIM}fail:${RESET}${WHITE}${FAIL_N}${RESET} ${DIM}sig:${RESET}${WHITE}${SIG_N}${RESET} ${DIM}sys:${RESET}${WHITE}${SYS_N}${RESET} ${DIM}algo:${RESET}${WHITE}${ALGO_N}${RESET} ${DIM}syn:${RESET}${WHITE}${SYN_N}${RESET}\n"

# ── divider ──
printf "${DIM}────────────────────────────────────────────────────────────────────────────────${RESET}\n"

exit 0
