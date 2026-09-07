#!/usr/bin/env bash
# PreToolUse hook for the AskUserQuestion tool.
# Hook reference: https://code.claude.com/docs/en/hooks
#
# Exit status 2 is the only PreToolUse result that both blocks the tool call
# and returns stderr to the model as the reason. Status 1 logs a non-blocking
# error; status 0 lets the call through.
set -euo pipefail

cat >&2 <<'MSG'
BLOCKED: the AskUserQuestion tool is banned in this environment and the user will never answer it. Do not retry it and do not rephrase the same call. Present the options as a numbered list in your chat reply instead, mutually exclusive, and wait for a numeric answer.
MSG

exit 2
