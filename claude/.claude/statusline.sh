#!/usr/bin/env bash
# Claude Code status line. Receives session JSON on stdin, prints two lines.
# Input schema: https://code.claude.com/docs/en/statusline
#
# Powerline-style segments styled after the Tokyo Night palette used by the
# @owloops/claude-powerline tool this replaces. The arrow separator (U+E0B0)
# is a Nerd Font glyph, not plain Unicode — relies on the terminal font
# already used to render that tool's identical arrows.
set -euo pipefail

input=$(cat)

IFS=$'\t' read -r model effort dir ctx cost p5 r5 p7 <<<"$(jq -r '
  [
    .model.display_name // "?",
    .effort.level // "",
    .workspace.current_dir // ".",
    (.context_window.used_percentage // 0 | floor),
    (.cost.total_cost_usd // 0),
    (.rate_limits.five_hour.used_percentage // -1 | floor),
    (.rate_limits.five_hour.resets_at // 0),
    (.rate_limits.seven_day.used_percentage // -1 | floor)
  ] | @tsv' 2>/dev/null <<<"$input")"

# malformed or empty stdin leaves every field blank; fail closed with no output
# rather than crash on the empty-array read below (bash 3.2, macOS's default,
# raises "unbound variable" on `"${arr[@]}"` for a zero-element array)
[[ -z $model ]] && exit 0

ESC=$'\033'
ARROW=$''
fg() { printf '%s[38;2;%sm' "$ESC" "$1"; }
bg() { printf '%s[48;2;%sm' "$ESC" "$1"; }
rst() { printf '%s[0m' "$ESC"; }

FG_DIR='122;162;247'   # blue
FG_GIT='158;206;106'   # green
FG_MODEL='187;154;247' # purple
FG_CTX='125;207;255'   # cyan
FG_5H='140;165;240'    # blue
FG_COST='115;218;202'  # teal
FG_7D='150;200;250'    # blue
FG_MUTED='169;177;214' # muted lavender

BG_DIR='42;46;74'
BG_GIT='32;34;50'
BG_MODEL='27;28;42'
BG_CTX='36;38;56'
BG_5H='34;37;58'
BG_COST='27;42;40'
BG_7D='30;33;52'

# green below 50 %, yellow below 80 %, red above
pct() {
  local p=$1 color
  if   (( p >= 80 )); then color='247;118;142'
  elif (( p >= 50 )); then color='224;175;104'
  else                     color='158;206;106'
  fi
  printf '%s%s%%' "$(fg "$color")" "$p"
}

seg() { printf '%s %s %s' "$(bg "$1")" "$2" "$(rst)"; }
arrow() {
  if [[ -n ${2:-} ]]; then printf '%s%s%s%s' "$(fg "$1")" "$(bg "$2")" "$ARROW" "$(rst)"
  else                     printf '%s%s%s' "$(fg "$1")" "$ARROW" "$(rst)"
  fi
}

# fish-style directory: ~/Projects/clients/acmeinc/slp → ~/P/c/b/slp
short_dir=${dir/#$HOME/\~}
short_dir=$(sed -E 's|([^/])[^/]*/|\1/|g' <<<"$short_dir")

git_text=""
if branch=$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null); then
  git_text="⎇ $branch"
  if counts=$(git -C "$dir" rev-list --left-right --count '@{upstream}...HEAD' 2>/dev/null); then
    behind=${counts%%$'\t'*}
    ahead=${counts##*$'\t'}
    if [[ $ahead -gt 0 || $behind -gt 0 ]]; then
      [[ $ahead  -gt 0 ]] && git_text+=" ↑$ahead"
      [[ $behind -gt 0 ]] && git_text+=" ↓$behind"
    else
      git_text+=" •"
    fi
  fi
elif sha=$(git -C "$dir" rev-parse --short HEAD 2>/dev/null); then
  git_text="⎇ $sha (detached)"
fi

# strip the "claude-" vendor prefix and join trailing version numbers with a
# dot: "claude-opus-4-8" → "Opus 4.8"
clean_model=$(sed -E 's/^claude-//' <<<"$model")
IFS='-' read -ra parts <<<"$clean_model"
prev_numeric=0
name=""
if [[ ${#parts[@]} -gt 0 ]]; then
  for p in "${parts[@]}"; do
    if [[ $p =~ ^[0-9]+$ ]]; then
      if [[ $prev_numeric -eq 1 ]]; then name+=".$p"; else name+=" $p"; fi
      prev_numeric=1
    else
      name+=" $(tr '[:lower:]' '[:upper:]' <<<"${p:0:1}")${p:1}"
      prev_numeric=0
    fi
  done
fi
clean_model=${name# }

line1="$(seg "$BG_DIR" "$(fg "$FG_DIR")$short_dir")"
line1+="$(arrow "$BG_DIR" "$BG_GIT")"
line1+="$(seg "$BG_GIT" "$(fg "$FG_GIT")$git_text")"
line1+="$(arrow "$BG_GIT" "$BG_MODEL")"
model_text="$(fg "$FG_MODEL")✻ $clean_model"
[[ -n $effort ]] && model_text+="$(fg "$FG_MUTED") ($effort)"
line1+="$(seg "$BG_MODEL" "$model_text")"
line1+="$(arrow "$BG_MODEL" "$BG_CTX")"
line1+="$(seg "$BG_CTX" "$(fg "$FG_CTX")§ $(pct "$ctx")")"
line1+="$(arrow "$BG_CTX" "")"
printf '%s\n' "$line1"

# rate limits are absent on API-key billing; -1 sentinel skips those segments
line2=""
lastbg=""
if [[ $p5 -ge 0 ]]; then
  now=$(date +%s)
  remaining=$(( r5 > 0 ? r5 - now : 0 ))
  (( remaining < 0 )) && remaining=0
  dur="$(( remaining / 3600 ))h $(( (remaining % 3600) / 60 ))m"
  line2+="$(seg "$BG_5H" "$(fg "$FG_5H")▤ $(pct "$p5")$(fg "$FG_MUTED") ($dur)")"
  lastbg=$BG_5H
  line2+="$(arrow "$lastbg" "$BG_COST")"
fi
line2+="$(seg "$BG_COST" "$(fg "$FG_COST")◉ \$$(printf '%.2f' "$cost")")"
lastbg=$BG_COST
if [[ $p7 -ge 0 ]]; then
  line2+="$(arrow "$lastbg" "$BG_7D")"
  line2+="$(seg "$BG_7D" "$(fg "$FG_7D")◐ $(pct "$p7")")"
  lastbg=$BG_7D
fi
line2+="$(arrow "$lastbg" "")"
printf '%s\n' "$line2"
