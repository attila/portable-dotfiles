#!/bin/zsh
#
# .zshenv - Zsh environment file, loaded always.
#

# NOTE: .zshenv needs to live at ~/.zshenv, not in $ZDOTDIR.

export XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}
export XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
export XDG_CACHE_HOME=${XDG_CACHE_HOME:-$HOME/.cache}
export ZDOTDIR=${ZDOTDIR:-$XDG_CONFIG_HOME/zsh}

# Foundational defaults
export EDITOR=vi
export VISUAL=vi
export PAGER=less

export HISTSIZE=50000
export SAVEHIST=50000
export HIST_IGNORE_DUPS=true

# Homebrew
export HOMEBREW_NO_UPGRADE_AUTO_UPDATES_CASKS=1

# Proto
export PROTO_HOME="$HOME/.proto"

# Ensure path arrays do not contain duplicates.
typeset -gU path fpath

# Set the list of directories that zsh searches for commands.
path=(
    $HOME/{,s}bin(N)
    $HOME/.local/{,s}bin(N)

    /opt/homebrew/opt/rustup/bin
    $HOME/.cargo/bin

    /opt/{homebrew,local}/{,s}bin(N)
    /home/linuxbrew/.linuxbrew/{,s}bin(N)
    /usr/local/{,s}bin(N)

    $PROTO_HOME/shims
    $PROTO_HOME/bin

    $path
)
