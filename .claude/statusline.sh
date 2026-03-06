#!/bin/bash
tmpfile=$(mktemp)
cat > "$tmpfile"
trap "rm -f '$tmpfile'" EXIT

# Extract all fields in a single jq call for speed
IFS=$'\t' read -r cwd project model_id used ctx_size session_id <<< "$(jq -r '[
  .workspace.current_dir,
  .workspace.project_dir,
  (.model.id // ""),
  (.context_window.used_percentage // 0 | floor | tostring),
  (.context_window.context_window_size // 200000 | tostring),
  (.session_id // "")
] | join("\t")' "$tmpfile")"

# Format token count as shorthand (e.g. 200000 -> 200k)
fmt_k() {
  local n=$1
  if [ "$n" -ge 1000000 ]; then
    printf "%s.%sM" "$((n / 1000000))" "$(( (n % 1000000) / 100000 ))"
  elif [ "$n" -ge 1000 ]; then
    printf "%sk" "$((n / 1000))"
  else
    printf "%s" "$n"
  fi
}

# Build directory display: parent/folder
parent=$(dirname "$cwd")
dir="$(basename "$parent")/$(basename "$cwd")"

# Terminal width for right-alignment (subtract 7: 6 for UI chrome + 1 for newline)
width=$(stty size </dev/tty 2>/dev/null | awk '{print $2}')
width=${width:-80}
width=$((width - 6))

# --- LINE 1: dir + git | model + tokens + context ---

left=$(printf "\033[34m%s\033[0m" "$dir")
left_plain="$dir"

# Git info with 5-second cache
CACHE_FILE="/tmp/statusline-git-cache"
CACHE_MAX_AGE=5

cache_is_stale() {
  [ ! -f "$CACHE_FILE" ] || \
  [ $(($(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0))) -gt $CACHE_MAX_AGE ]
}

if cache_is_stale; then
  if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null \
      || git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
    dirty=$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)
    [ -n "$dirty" ] && dirty_flag="1" || dirty_flag="0"
    echo "$branch|$dirty_flag" > "$CACHE_FILE"
  else
    echo "|" > "$CACHE_FILE"
  fi
fi

IFS='|' read -r branch dirty_flag < "$CACHE_FILE"

if [ -n "$branch" ]; then
  left="$left$(printf " \033[35mon\033[0m \033[1;35m%s\033[0m" "$branch")"
  left_plain="$left_plain on $branch"
  if [ "$dirty_flag" = "1" ]; then
    left="$left$(printf " \033[33m*\033[0m")"
    left_plain="$left_plain *"
  fi
fi

# Build right side: model_id · used_k/total_k tokens (pct%)
used_tokens=$((ctx_size * used / 100))
used_k=$(fmt_k "$used_tokens")
total_k=$(fmt_k "$ctx_size")
right_plain="${model_id} · ${used_k}/${total_k} tokens (${used}%)"
right="$right_plain"

# Right-align line 1, but collapse when context >= 60% to leave room for notifications
left_len=${#left_plain}
right_len=${#right_plain}
if [ "$used" -ge 60 ]; then
  echo "$(printf "%s  %s" "$left" "$right")"
else
  pad=$((width - left_len - right_len))
  [ "$pad" -lt 1 ] && pad=1
  echo "$(printf "%s%${pad}s%s" "$left" "" "$right")"
fi

# --- LINE 2: session_id + transcript_path ---

sid_len=${#session_id}
sid_pad=$((width - sid_len))
[ "$sid_pad" -lt 1 ] && sid_pad=1
printf "\033[2m%${width}s\033[0m" "$session_id"
