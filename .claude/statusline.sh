#!/usr/bin/env bash
# Claude Code status line: model + context-window and weekly-usage widgets.
# Reads the session JSON on stdin (see code.claude.com/docs/en/statusline).
set -euo pipefail

input=$(cat)

# The seven_day window is absent until the first API response and after it
# resets. -1 marks that: an empty field would collapse under IFS, and 0 would
# read as "0% used".
IFS=$'\t' read -r model pct week_used reset < <(
  echo "$input" | jq -r '
    [ (.model.display_name // "?"),
      (.context_window.used_percentage // 0 | floor),
      (.rate_limits.seven_day.used_percentage // -1 | floor),
      (.rate_limits.seven_day.resets_at // 0)
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

# Weekly allowance used and its reset, e.g.
# "63%  week used  (resets Thu 14:00, in 2d4h)".
week=""
now=$(date +%s)
if [ "$week_used" -ge 0 ] && [ "$reset" -gt "$now" ]; then
  mins=$(( (reset - now) / 60 ))
  if   [ "$mins" -ge 1440 ]; then until_reset="$(( mins / 1440 ))d$(( mins % 1440 / 60 ))h"
  elif [ "$mins" -ge 60 ];   then until_reset="$(( mins / 60 ))h$(( mins % 60 ))m"
  else                            until_reset="${mins}m"
  fi
  week="   $(bar "$week_used")  ${dim}week used  (resets $(date -d "@$reset" '+%a %H:%M'), in ${until_reset})${clear}"
fi

printf '%s  %s  %sctx%s%s\n' "$model" "$(bar "$pct")" "$dim" "$clear" "$week"
