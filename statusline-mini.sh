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

iso_to_epoch() {
  local iso_str="$1"
  local epoch
  epoch=$(date -d "${iso_str}" +%s 2>/dev/null)
  if [ -n "$epoch" ]; then echo "$epoch"; return 0; fi

  local stripped="${iso_str%%.*}"
  stripped="${stripped%%Z}"
  stripped="${stripped%%+*}"
  stripped="${stripped%%-[0-9][0-9]:[0-9][0-9]}"

  if [[ "$iso_str" == *"Z"* ]] || [[ "$iso_str" == *"+00:00"* ]] || [[ "$iso_str" == *"-00:00"* ]]; then
    epoch=$(env TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "$stripped" +%s 2>/dev/null)
  else
    epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$stripped" +%s 2>/dev/null)
  fi
  [ -n "$epoch" ] && { echo "$epoch"; return 0; }
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
  if [ -n "$CLAUDE_CODE_OAUTH_TOKEN" ]; then echo "$CLAUDE_CODE_OAUTH_TOKEN"; return 0; fi
  if command -v security >/dev/null 2>&1; then
    local blob
    blob=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
    if [ -n "$blob" ]; then
      token=$(echo "$blob" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
      if [ -n "$token" ] && [ "$token" != "null" ]; then echo "$token"; return 0; fi
    fi
  fi
  local creds_file="${HOME}/.claude/.credentials.json"
  if [ -f "$creds_file" ]; then
    token=$(jq -r '.claudeAiOauth.accessToken // empty' "$creds_file" 2>/dev/null)
    if [ -n "$token" ] && [ "$token" != "null" ]; then echo "$token"; return 0; fi
  fi
  if command -v secret-tool >/dev/null 2>&1; then
    local blob
    blob=$(timeout 2 secret-tool lookup service "Claude Code-credentials" 2>/dev/null)
    if [ -n "$blob" ]; then
      token=$(echo "$blob" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
      if [ -n "$token" ] && [ "$token" != "null" ]; then echo "$token"; return 0; fi
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
  CTX_DISPLAY="?/?"
fi

# Context color
if [ "$CTX_PCT" -lt 40 ] 2>/dev/null; then
  CTX_COLOR="$GREEN"
elif [ "$CTX_PCT" -lt 60 ] 2>/dev/null; then
  CTX_COLOR="$YELLOW"
else
  CTX_COLOR="$RED"
fi

CTX_BAR=$(build_bar "$CTX_PCT" 20)

# CWD
PWD_VAL=$(echo "$input" | jq -r '.cwd // .workspace.current_dir // "?"')
PWD_SHORT="$PWD_VAL"
case "$PWD_VAL" in "$HOME"*) PWD_SHORT="~${PWD_VAL#$HOME}" ;; esac

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

# Network info (cached 60s)
net_cache="/tmp/claude/statusline-net-cache.txt"
HOSTNAME_VAL=""
WIFI_IP=""
ETH_IP=""

net_needs_refresh=true
if [ -f "$net_cache" ]; then
  net_mtime=$(stat -c %Y "$net_cache" 2>/dev/null || stat -f %m "$net_cache" 2>/dev/null)
  net_now=$(date +%s)
  net_age=$(( net_now - net_mtime ))
  if [ "$net_age" -lt 60 ]; then net_needs_refresh=false; fi
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
              ip -4 addr show wlp0s20f3 2>/dev/null | grep -oP 'inet \K[^/]+' || echo "")
    ETH_IP=$(ip -4 addr show eth0 2>/dev/null | grep -oP 'inet \K[^/]+' || \
             ip -4 addr show enp0s31f6 2>/dev/null | grep -oP 'inet \K[^/]+' || \
             ip -4 addr show eno1 2>/dev/null | grep -oP 'inet \K[^/]+' || echo "")
    if [ -z "$WIFI_IP" ] && [ -z "$ETH_IP" ]; then
      ETH_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    fi
  fi
  mkdir -p /tmp/claude
  printf "%s\n%s\n%s" "$HOSTNAME_VAL" "$WIFI_IP" "$ETH_IP" > "$net_cache"
else
  HOSTNAME_VAL=$(sed -n '1p' "$net_cache")
  WIFI_IP=$(sed -n '2p' "$net_cache")
  ETH_IP=$(sed -n '3p' "$net_cache")
fi

# Thinking effort
EFFORT="default"
SETTINGS_PATH="$HOME/.claude/settings.json"
if [ -f "$SETTINGS_PATH" ]; then
  EFFORT=$(jq -r '.effortLevel // "default"' "$SETTINGS_PATH" 2>/dev/null)
fi
EFFORT_STR=""
case "$EFFORT" in
  high)   EFFORT_STR="${MAGENTA}● high${RESET}" ;;
  medium) EFFORT_STR="${DIM}◑ medium${RESET}" ;;
  low)    EFFORT_STR="${DIM}◔ low${RESET}" ;;
  *)      EFFORT_STR="${DIM}◑ default${RESET}" ;;
esac

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

# ══════════════════════════════════════════════════════
# ── OUTPUT: Mini layout ──────────────────────────────
# ══════════════════════════════════════════════════════

# MODEL + CONTEXT on same line
printf "${MAGENTA}⬡${RESET} ${CYAN}${MODEL}${RESET}${SEP}${EFFORT_STR}${SEP}${GREEN}⛁${RESET} ${CTX_COLOR}${CTX_PCT}%%${RESET} ${DIM}${CTX_DISPLAY}${RESET}\n"

# NET + PWD on same line
NET_PART="${MAGENTA}${HOSTNAME_VAL}${RESET}"
[ -n "$WIFI_IP" ] && NET_PART+="${SEP}${GREEN}w${RESET}${WHITE}${WIFI_IP}${RESET}"
[ -n "$ETH_IP" ] && NET_PART+="${SEP}${CYAN}e${RESET}${WHITE}${ETH_IP}${RESET}"

PWD_PART="${CYAN}${PWD_SHORT}${RESET}"
[ -n "$GIT_BRANCH" ] && PWD_PART+="${SEP}${GREEN}${GIT_BRANCH}${RESET}"

printf "${BLUE}◇${RESET} ${NET_PART}${SEP}${GREEN}◆${RESET} ${PWD_PART}\n"

# USAGE
if [ -n "$rate_lines" ]; then
  printf "%b\n" "$rate_lines"
fi

exit 0
