#!/usr/bin/env bash
# Claude Code status line: model + context-window and session-usage widgets.
# Reads the session JSON on stdin (see code.claude.com/docs/en/statusline).
set -euo pipefail

input=$(cat)

IFS=$'\t' read -r model pct session reset < <(
  echo "$input" | jq -r '
    [ (.model.display_name // "?"),
      (.context_window.used_percentage // 0 | floor),
      (.rate_limits.five_hour.used_percentage // 0 | floor),
      (.rate_limits.five_hour.resets_at // 0)
    ] | @tsv
  '
)

dim=$'\033[2m'; clear=$'\033[0m'

# bar PCT -> prints a colored 10-cell progress bar. Color by pressure:
# green < 50, yellow < 80, red otherwise.
bar() {
  local p=$1 c filled i out=""
  if   [ "$p" -lt 50 ]; then c=$'\033[32m'
  elif [ "$p" -lt 80 ]; then c=$'\033[33m'
  else                       c=$'\033[31m'
  fi
  filled=$(( (p + 5) / 10 ))
  [ "$filled" -gt 10 ] && filled=10
  out="$c"
  for ((i=0; i<filled; i++));  do out+="▓"; done
  out+="$dim"
  for ((i=filled; i<10; i++)); do out+="░"; done
  printf '%s%s  %s%d%%%s' "$out" "$clear" "$c" "$p" "$clear"
}

# Time until the 5h rate-limit window resets, e.g. "(3h10m)".
now=$(date +%s)
if [ "$reset" -gt "$now" ]; then
  mins=$(( (reset - now) / 60 ))
  if [ "$mins" -ge 60 ]; then left="$(( mins / 60 ))h$(( mins % 60 ))m"; else left="${mins}m"; fi
  resetfmt=" ${dim}(${left})${clear}"
else
  resetfmt=""
fi

printf '%s  %s  %sctx%s   %s  %ssession%s%s\n' \
  "$model" "$(bar "$pct")" "$dim" "$clear" \
  "$(bar "$session")" "$dim" "$clear" "$resetfmt"
