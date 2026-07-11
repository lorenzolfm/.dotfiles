#!/usr/bin/env bash
# Claude Code status line: model + context-window usage widget.
# Reads the session JSON on stdin (see code.claude.com/docs/en/statusline).
set -euo pipefail

input=$(cat)

IFS=$'\t' read -r model pct used window < <(
  echo "$input" | jq -r '
    def human(n): if n == null then "?"
      elif n >= 1000000 then ((n/1000000*10|floor)/10|tostring) + "M"
      elif n >= 1000 then ((n/1000)|floor|tostring) + "k"
      else (n|tostring) end;
    [ (.model.display_name // "?"),
      (.context_window.used_percentage // 0 | floor),
      human(.context_window.total_input_tokens),
      human(.context_window.context_window_size)
    ] | @tsv
  '
)

# Color the bar by pressure: green < 50, yellow < 80, red otherwise.
if   [ "$pct" -lt 50 ]; then color=$'\033[32m'
elif [ "$pct" -lt 80 ]; then color=$'\033[33m'
else                        color=$'\033[31m'
fi
dim=$'\033[2m'; reset=$'\033[0m'

filled=$(( (pct + 5) / 10 ))
[ "$filled" -gt 10 ] && filled=10
bar=""
for ((i=0; i<filled; i++));    do bar+="▓"; done
for ((i=filled; i<10; i++));   do bar+="░"; done

printf '%s  %s%s%s  %s%d%%%s  %s· %s/%s%s\n' \
  "$model" "$color" "$bar" "$reset" "$color" "$pct" "$reset" "$dim" "$used" "$window" "$reset"
