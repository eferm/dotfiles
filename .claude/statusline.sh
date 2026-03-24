#!/bin/bash
#
# Claude Code statusline script.
# Reads JSON session state from stdin and prints a formatted status line:
#   <dir> on <branch> [*]  <model> · <used>/<total> tokens (<pct>%)

readonly CACHE_FILE="/tmp/statusline-git-cache"
readonly CACHE_MAX_AGE=5  # seconds

# Format a number with k/M suffix (e.g., 200000 -> "200k", 1500000 -> "1.5M").
format_number() {
  local n="${1}"
  if (( n >= 1000000 )); then
    printf "%s.%sM" "$(( n / 1000000 ))" "$(( (n % 1000000) / 100000 ))"
  elif (( n >= 1000 )); then
    printf "%sk" "$(( n / 1000 ))"
  else
    printf "%s" "${n}"
  fi
}

# Return true if the git cache is missing or older than CACHE_MAX_AGE seconds.
cache_is_stale() {
  [[ ! -f "${CACHE_FILE}" ]] && return 0
  local file_mtime
  file_mtime=$(stat -f %m "${CACHE_FILE}" 2>/dev/null \
    || stat -c %Y "${CACHE_FILE}" 2>/dev/null \
    || echo 0)
  (( $(date +%s) - file_mtime > CACHE_MAX_AGE ))
}

# --- Read JSON from stdin ---

tmpfile=$(mktemp)
trap 'rm -f "$tmpfile"' EXIT
cat > "${tmpfile}"

# --- Extract fields from JSON ---

IFS=$'\t' read -r cwd model_id used_pct context_size <<< "$(
  jq -r '[
    .workspace.current_dir,
    (.model.id // ""),
    (.context_window.used_percentage // 0 | floor | tostring),
    (.context_window.context_window_size // 200000 | tostring)
  ] | join("\t")' "${tmpfile}"
)"

# --- Left side: directory and git info ---

parent="${cwd%/*}"
dir="${parent##*/}/${cwd##*/}"
left=$(printf "\033[34m%s\033[0m" "${dir}")

if cache_is_stale; then
  if git -C "${cwd}" rev-parse --git-dir >/dev/null 2>&1; then
    branch=$(git -C "${cwd}" --no-optional-locks branch --show-current 2>/dev/null \
      || git -C "${cwd}" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
    if [[ -n "$(git -C "${cwd}" --no-optional-locks status --porcelain 2>/dev/null)" ]]; then
      dirty_flag="1"
    else
      dirty_flag="0"
    fi
    echo "${branch}|${dirty_flag}" > "${CACHE_FILE}"
  else
    echo "|" > "${CACHE_FILE}"
  fi
fi

IFS='|' read -r branch dirty_flag < "${CACHE_FILE}"

if [[ -n "${branch}" ]]; then
  left+=$(printf " \033[35mon\033[0m \033[1;35m%s\033[0m" "${branch}")
  if [[ "${dirty_flag}" == "1" ]]; then
    left+=$(printf " \033[33m*\033[0m")
  fi
fi

# --- Right side: model and token usage ---

used_tokens=$(( context_size * used_pct / 100 ))
token_display="$(format_number "${used_tokens}")/$(format_number "${context_size}")"
right="${model_id} · ${token_display} tokens (${used_pct}%)"

# --- Output ---

printf "%s  %s\n" "${left}" "${right}"
