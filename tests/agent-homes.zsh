#!/usr/bin/env zsh
set -eu

repo_root=${0:A:h:h}
if [[ ${1:-} != --child ]]; then
    mkdir -p "$repo_root/tmp"
    work=$(mktemp -d "$repo_root/tmp/agent-homes.XXXXXX")
    mkdir "$work/.claude-personal" "$work/.claude-work" \
        "$work/.codex-personal" "$work/.codex-work"
    trap 'rmdir "$work/.claude-personal" "$work/.claude-work" "$work/.codex-personal" "$work/.codex-work" "$work"' EXIT
    env HOME="$work" zsh -f "$0" --child
    exit $?
fi

source "$repo_root/zsh/.config/zsh/.aliases"
calls=0
nono() {
    (( calls += 1 ))
    captured_args=("$@")
    captured_claude=${CLAUDE_CONFIG_DIR:-}
    captured_codex=${CODEX_HOME:-}
    return 17
}

for launcher in cc-lore cc-work cx-lore cx-work; do
    expected_profile=claude-code-personal
    expected_home="$HOME/.claude-personal"
    expected_agent=(claude)
    case $launcher in
        cc-work) expected_profile=claude-code-work; expected_home="$HOME/.claude-work" ;;
        cx-lore) expected_profile=codex-personal; expected_home="$HOME/.codex-personal" ;;
        cx-work) expected_profile=codex-work; expected_home="$HOME/.codex-work" ;;
    esac
    [[ $launcher != cx-* ]] || expected_agent=(codex --dangerously-bypass-approvals-and-sandbox)
    result_status=0
    eval "$launcher --extends docker-build -- 'prompt with spaces'" || result_status=$?
    [[ $result_status == 17 ]] || exit 1
    expected_args=(run --allow-cwd --profile "$expected_profile" --extends docker-build -- "${expected_agent[@]}" 'prompt with spaces')
    [[ ${#captured_args} == ${#expected_args} ]] || exit 1
    for (( i=1; i<=${#expected_args}; i++ )); do
        [[ ${captured_args[$i]} == ${expected_args[$i]} ]] || exit 1
    done
    if [[ $launcher == cx-* ]]; then
        [[ $captured_codex == "$expected_home" ]] || exit 1
    else
        [[ $captured_claude == "$expected_home" ]] || exit 1
    fi
    print "PASS: $launcher selects its home, preserves arguments and returns nono's status"
done

for launcher in _nono_claude _nono_codex; do
    before=$calls
    result_status=0
    "$launcher" test-profile "$HOME/missing home" >/dev/null 2>&1 || result_status=$?
    [[ $result_status == 1 && $calls == $before ]] || exit 1
    print "PASS: $launcher refuses a missing home without starting nono"
done
