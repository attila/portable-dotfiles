# portable-dotfiles

Read-only personal dotfiles for macOS, Linux, and remote coding environments.

This repository is shared for reference and reuse. Issues, pull requests, wiki
edits, support requests, and feature requests are not accepted.

## Included

| Module          | What it contains                                                                                                |
| --------------- | --------------------------------------------------------------------------------------------------------------- |
| `.ai/skills`    | Agent guidance for tools that understand repository-local instructions.                                         |
| `agents`        | Shared agent instructions exposed through Codex and Claude module links.                                        |
| `claude`        | [Claude Code](https://code.claude.com/docs/en/overview) instruction link pointing at the shared agent guidance. |
| `codex`         | [Codex](https://github.com/openai/codex) instruction link pointing at the shared agent guidance.                |
| `dprint`        | [dprint](https://dprint.dev/) formatter configuration used by the repository.                                   |
| `ghostty`       | [Ghostty](https://ghostty.org/) terminal settings.                                                              |
| `git`           | Git ignore defaults and commit message template.                                                                |
| `nono`          | Sandbox profiles for agent CLIs plus helper scripts used inside those sandboxes.                                |
| `starship`      | [Starship](https://starship.rs/) prompt settings.                                                               |
| `tmux`          | [tmux](https://tmux.us/) configuration tuned for terminal-based agent workflows.                                |
| `zsh`           | Shell startup, plugin list, theme, and PATH wiring for toolchain helpers.                                       |
| `Brewfile`      | [Homebrew](https://brew.sh/) package metadata for a development-focused workstation baseline.                   |
| `.editorconfig` | Editor defaults for indentation, line endings, and final newlines.                                              |

The repository is organised for [GNU Stow](https://www.gnu.org/software/stow/):
each top-level module maps onto the same relative path under `$HOME`. For
example, stowing `zsh` installs `zsh/.zshenv` as `~/.zshenv`, while stowing
`nono` installs the nono profiles under `~/.config/nono/profiles/`.

## nono Profiles

[`nono`](https://nono.sh) is a capability-based sandbox for running tools with
explicit filesystem, environment, and network access. The `nono` module contains
ready-to-adapt profiles under `nono/.config/nono/profiles/` for common
terminal-based agent workflows.

The profiles are examples, not universal defaults. Review the grants before
using them, especially filesystem write access, credential proxy settings,
keychain access, and macOS seatbelt rules. The included profiles cover a shared
base profile, public-dotfiles access, and agent-specific profiles for Codex,
Claude Code, and Crush.

### Docker Daemon Access

> **Warning:** The standalone `docker-build` profile grants access to the Docker
> daemon. This bypasses nono's host-filesystem policy: an agent can ask Docker
> to bind-mount a path that nono blocks and then read or modify that path from a
> container. Treat a session with this profile as having the host access
> available to the Docker daemon, not the narrower access shown by nono.

Add `docker-build` to an agent profile's `extends` array only for sessions that
need it. For example, use `"extends": ["codex-lore", "docker-build"]`. The
profile supports builds using public Docker Hub, GHCR, npm, and PyPI
dependencies; it deliberately leaves Docker client credentials blocked.

Contain the daemon authority rather than relying on the agent to avoid unsafe
commands:

1. Use a dedicated remote BuildKit endpoint and grant the sandbox access to that
   endpoint instead of the Docker daemon. This is the preferred option for
   build-only workflows.
2. Use a separate disposable VM or daemon with host-directory sharing disabled.
   A compromised build then controls that environment rather than the
   workstation filesystem.
3. Put a fail-closed API proxy in front of Docker and reject container creation
   and bind mounts. Validate the complete BuildKit protocol before relying on
   this: upgraded or gRPC sessions can escape incomplete HTTP endpoint filters.

Rootless Docker reduces daemon privilege but still exposes files readable by the
host user. Restricting the `docker` CLI command is also insufficient because
software can call the daemon socket directly.

Before using the profiles, adapt the machine-local pieces:

- Install the matching nono package profiles for the agent CLIs you use, such as
  `codex`, `claude-code`, and `default`.
- Update absolute macOS seatbelt paths such as `/Users/username` to your actual
  home directory when a literal home-directory grant is required.
- Configure Git identity and signing outside the sandbox, then make sure the
  sandbox can read the Git config and reach the GPG agent socket if you use
  signed commits.
- Store API keys in nono's credential store or your OS secret store, then expose
  them through profile `network.credentials`, `network.custom_credentials`, or
  `env_credentials` as appropriate. Do not place real tokens in profile JSON.
- Review profile inheritance before changing grants. The shared `root` profile
  contains most common toolchain, network, environment, and URL-opening policy;
  agent profiles should add only agent-specific access.
- Run the helper smoke test after stowing the `nono` module or changing zsh PATH
  wiring:

  ```sh
  nono/.local/share/nono-helpers/smoke-test.sh
  ```

The helper files under `nono/.local/share/nono-helpers/` support the profiles.
In particular, the `node` wrapper injects the proxy bootstrap only when
`HTTPS_PROXY` is set, so Node-based tools can use the sandbox proxy while normal
shells keep using the real Node runtime.

The zsh module wires that helper directory into PATH in two places:

- `.zshenv` sets the initial PATH for login and non-interactive zsh.
- `.zshrc` re-prepends the helper directory after proto updates PATH while
  changing project directories.

The profiles assume the zsh module is stowed too. Without the zsh PATH wiring,
the Node wrapper may not shadow Homebrew or proto-managed Node consistently, and
Node-based SDKs may bypass the sandbox proxy.

Agents that understand repository-local skills can use
`onboard-portable-dotfiles` to guide a selective setup.

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
