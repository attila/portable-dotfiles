# Make plugin folder names pretty
zstyle ':antidote:bundle' use-friendly-names 'yes'

# Zephyr defaults to the Starship-backed theme. Use zsh's built-in default
# prompt when Starship is not installed.
if command -v starship >/dev/null 2>&1; then
    zstyle ':zephyr:plugin:prompt' theme starship zephyr
else
    zstyle ':zephyr:plugin:prompt' theme default
fi

# fzf
if command -v fzf >/dev/null 2>&1; then
    source <(fzf --zsh)
fi

# antidote
#
# Resolve Homebrew prefix from known locations without an environment
# dependency.
if [[ -z ${HOMEBREW_PREFIX} ]]; then
    if [[ -d /opt/homebrew ]]; then
        HOMEBREW_PREFIX=/opt/homebrew
    elif [[ -d /home/linuxbrew/.linuxbrew ]]; then
        HOMEBREW_PREFIX=/home/linuxbrew/.linuxbrew
    else
        HOMEBREW_PREFIX=/usr/local
    fi
fi
antidote_zsh="${HOMEBREW_PREFIX}/opt/antidote/share/antidote/antidote.zsh"
[[ -r $antidote_zsh ]] && source "$antidote_zsh"

# Source the static bundle directly. To regenerate after editing
# .zsh_plugins.txt, run: antidote load
zsh_plugins=${ZDOTDIR:-${HOME}/.config/zsh}/.zsh_plugins.zsh
if [[ -f $zsh_plugins ]]; then
    source $zsh_plugins
elif (( $+functions[antidote] )); then
    antidote load
fi

# Load optional local aliases when present.
aliases_file=${ZDOTDIR:-${HOME}/.config/zsh}/.aliases
if [[ -r $aliases_file ]]; then
    source "$aliases_file"
fi

# Proto
if command -v proto >/dev/null 2>&1; then
    source <(proto completions --shell zsh)

    # Find the active proto config cheaply; `proto activate` is too slow for
    # every `cd`, so the hook uses this path as its constant-size cache key.
    _proto_find_config() {
        REPLY=
        local dir=$PWD
        while [[ $dir != / ]]; do
            if [[ -f $dir/.prototools ]]; then
                REPLY=$dir/.prototools
                return
            fi
            dir=${dir:h}
        done
    }

    # Recompute proto's exported environment only when crossing a `.prototools`
    # boundary; subdirectory hops inside the same project stay cheap.
    _proto_activate_hook() {
        local config output
        _proto_find_config
        config=$REPLY
        if [[ ${_proto_active_config+x} == x && $_proto_active_config == "$config" ]]; then
            return
        fi

        trap '' SIGINT
        output=$(proto activate zsh --export) || {
            trap - SIGINT
            return
        }
        if [[ -n $output ]]; then
            eval "$output"
        fi
        trap - SIGINT
        _proto_active_config=$config
    }

    # Single scalar cache of the current `.prototools` path; it does not grow
    # with long-lived shells or many directory changes.
    typeset -g _proto_active_config
    typeset -ag chpwd_functions
    if (( ! ${chpwd_functions[(I)_proto_activate_hook]} )); then
        chpwd_functions=(_proto_activate_hook $chpwd_functions)
    fi

    _proto_activate_hook
fi

# Keep nono-helpers/bin at the front of PATH so the `node` wrapper takes
# precedence over the real node. The wrapper injects
# --import=proxy-bootstrap.mjs only when HTTPS_PROXY is set; outside a sandbox
# it is a transparent pass-through.
#
# This lives in .zshrc as well as .zshenv because macOS /etc/zprofile can
# reorder PATH after .zshenv, and proto can re-prepend its shims when changing
# directories. Register after proto's chpwd hook so the wrapper wins the final
# PATH position.
_nono_helpers_prepend_path() {
    path=($HOME/.local/share/nono-helpers/bin $path)
}
typeset -ag chpwd_functions
if (( ! ${chpwd_functions[(I)_nono_helpers_prepend_path]} )); then
    chpwd_functions=($chpwd_functions _nono_helpers_prepend_path)
fi
_nono_helpers_prepend_path
