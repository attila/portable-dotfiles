# portable-dotfiles

Read-only personal dotfiles for macOS, Linux, and remote coding environments.

This repository is shared for reference and reuse. Issues, pull requests, wiki
edits, support requests, and feature requests are not accepted.

## Included

- Ghostty terminal settings.
- Git ignore defaults and commit message template.
- Starship prompt settings.
- tmux configuration.
- zsh environment, plugin list, theme, and public-safe shell startup.
- Formatter and Homebrew package metadata.

## Install

Install GNU Stow, then stow the modules you want from the repository root.

```sh
brew bundle
stow ghostty
stow git
stow starship
stow tmux
stow zsh
```

Use `stow -D <module>` to remove a module's symlinks and `stow -R <module>` to
restow after local edits.
