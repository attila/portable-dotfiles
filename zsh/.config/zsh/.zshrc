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
