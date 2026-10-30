#!/usr/bin/env bash
# Anthropic API key source for the ~/.claude-api home, in two roles:
# - Claude Code's apiKeyHelper, for claude-api and inside cc-api;
# - nono's supervisor-side credential capture command for cc-api.
# Settings reference: https://code.claude.com/docs/en/settings
#
# Inside cc-api the key file is outside every sandbox grant. nono exposes a
# phantom key instead and swaps in the real one on requests to
# api.anthropic.com, so the phantom must win whenever it is present.
set -euo pipefail

if [[ -n "${NONO_ANTHROPIC_API_KEY:-}" ]]; then
  printf '%s\n' "$NONO_ANTHROPIC_API_KEY"
  exit 0
fi

key_file="${XDG_CONFIG_HOME:-$HOME/.config}/secrets/anthropic-api-key"

if [[ ! -e "$key_file" ]]; then
  printf 'anthropic-api-key: no key file at %s\n' "$key_file" >&2
  exit 1
fi

if [[ "$OSTYPE" == darwin* ]]; then
  mode="$(stat -f '%Lp' "$key_file")"
else
  mode="$(stat -c '%a' "$key_file")"
fi

if [[ "$mode" != "600" ]]; then
  printf 'anthropic-api-key: refusing %s: mode %s, expected 600\n' \
    "$key_file" "$mode" >&2
  exit 1
fi

cat -- "$key_file"
