# portable-dotfiles

Read-only personal dotfiles for macOS, Linux, and remote coding environments.

This repository is shared for reference and reuse. Issues, pull requests, wiki
edits, support requests, and feature requests are not accepted.

## Included

| Module          | What it contains                                                                                                |
| --------------- | --------------------------------------------------------------------------------------------------------------- |
| `.ai/skills`    | Agent guidance for tools that understand repository-local instructions.                                         |
| `agents`        | Shared agent instructions exposed through Codex and Claude module links.                                        |
| `bin`           | Small user commands, including NVMe snapshot trend reporting.                                                   |
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

### Separate Personal and Work Homes

The zsh module provides four launchers:

| Launcher  | Profile                | Home                 |
| --------- | ---------------------- | -------------------- |
| `cc-lore` | `claude-code-personal` | `~/.claude-personal` |
| `cc-work` | `claude-code-work`     | `~/.claude-work`     |
| `cx-lore` | `codex-personal`       | `~/.codex-personal`  |
| `cx-work` | `codex-work`           | `~/.codex-work`      |

Each profile allows its own home and denies the other home for that agent and
the legacy default home. The launchers refuse missing homes. Shared toolchain
grants, keychain access and repository instructions remain shared; these
profiles separate agent homes, not every resource on the machine. Work profiles
contain no organisation credentials or service-specific grants.

After reviewing and stowing `agents`, `nono` and `zsh`, initialise fresh homes:

```sh
mkdir -m 700 -p ~/.claude-personal ~/.claude-work ~/.codex-personal ~/.codex-work
for dir in ~/.claude-personal ~/.claude-work; do
    ln -s "$HOME/.config/AGENTS.md" "$dir/CLAUDE.md"
done
for dir in ~/.codex-personal ~/.codex-work; do
    ln -s "$HOME/.config/AGENTS.md" "$dir/AGENTS.md"
    (set -C; printf '%s\n' 'cli_auth_credentials_store = "file"' \
        'mcp_oauth_credentials_store = "file"' > "$dir/config.toml")
done
```

The configuration writes refuse to overwrite existing files. Keep credentials,
session history and mutable plugin state inside each home; install plugins and
skills separately instead of linking back to a legacy home. Existing sessions
are left where they are. Codex's file credential stores keep new Codex and MCP
logins inside their respective homes.

Stow the `claude` module once both Claude homes exist. It installs a
`settings.json` into each home that wires the status line and a `PreToolUse`
hook denying the `AskUserQuestion` tool, so the agent offers its options in chat
instead. Stowing it before the homes exist symlinks the whole home directory,
which leaves mutable agent state inside the repository.

```sh
stow claude
```

Open a new shell. Start `cc-lore` and `cc-work` to authenticate Claude in each
home; use `cx-lore -- login` and `cx-work -- login` for Codex. A local home name
does not select an online account or workspace: choose the intended identity
during each login.

Arguments before `--` go to nono; arguments after it go to the agent. For
example, `cx-work -- --model gpt-5` passes a model option to Codex. Codex's own
sandbox is disabled by these launchers because nono provides the boundary.
Docker access is opt-in through `--extends docker-build` before `--`, and has
the broader authority described above.

### Claude Background-Session Daemon

Claude Code's `claude --bg` dispatches a background worker session, and
`claude agents` lists and reconnects to them. Both reach a per-home supervisor
over a unix socket. Under nono, connecting to that socket is mediated separately
from filesystem access, so a client needs an explicit `unix_socket_subtree`
grant even when it can already read the containing directory.

No shipped profile carries this grant, because the socket directory name embeds
a digest of your own configuration directory path. Derive yours:

```sh
printf '%s' "$HOME/.claude" | shasum -a 256 | cut -c1-8
```

The socket directory is `/tmp/cc-daemon-$(id -u)/<that-digest>`. Substitute your
own `CLAUDE_CONFIG_DIR` path if you do not use the default. Add a connect-only
grant for it to the client profile:

```json
{
  "filesystem": {
    "unix_socket_subtree": [
      { "path": "/tmp/cc-daemon-1000/0123abcd", "when": "macos" }
    ]
  }
}
```

Host the supervisor inside the sandbox, under the same profile its clients use,
adding the bind-capable grant as a launcher flag:

```sh
nono run --allow-cwd --profile <client-profile> \
  --allow-unix-socket-subtree-bind /tmp/cc-daemon-1000/0123abcd \
  -- claude daemon run
```

> **Why not run the daemon on the host?** Workers are children of the supervisor
> and inherit its sandbox policy and environment rather than the dispatching
> client's. A supervisor started from an unsandboxed shell runs its workers with
> full host authority, which removes the sandbox for every client holding the
> connect grant. Host it under the narrowest profile any of its clients use.

Three behaviours are worth knowing before relying on this:

- Any process inside a granted sandbox can list, dispatch, stop, and read the
  logs of that home's background sessions. The grant's boundary is the
  configuration home, not the individual session.
- nono attaches a unix-socket grant only when the path already exists. A grant
  for a missing path is skipped with a log line naming the path, and the sandbox
  then runs without that grant and without an error. Because `/tmp` is cleared
  on reboot and the supervisor removes its socket directory when it stops,
  create the directory before starting either the host or a client.
- A client that dispatches with no host running auto-starts a transient
  supervisor whose nono proxy dies with the client. Its workers reach state
  `blocked` and log `Unable to connect to API (ConnectionRefused)`. Start the
  host first. A supervisor you start deliberately runs until you stop it; the
  idle timeout applies only to the transient kind. Stop either kind with
  `claude daemon stop --any`, because plain `claude daemon stop` refuses
  whenever no background service is installed. A stopping supervisor removes its
  socket directory, which is why the directory has to be recreated before the
  next start.

Inside a sandbox the `claude daemon status` header reads `not running` because
process-information isolation blocks its process probe. The `bg sessions` block
on the same output is accurate.

### GPG Signing Diagnostics

`gpg-signing-diagnose` captures agent-socket and signing evidence without
starting, restarting, or killing `gpg-agent`. On macOS it also reports whether
the socket has a listener and classifies common stale-socket and access
failures.

Run it immediately after a failed signed commit, before retrying:

```sh
gpg-signing-diagnose
```

## Install

Install GNU Stow, then stow the modules you want from the repository root.

```sh
brew bundle
stow ghostty
stow git
stow bin
stow claude
stow starship
stow tmux
stow zsh
```

Use `stow -D <module>` to remove a module's symlinks and `stow -R <module>` to
restow after local edits.

## NVMe Health Report

The `bin` module installs `nvme-health-report`, a POSIX shell and `jq` command
that reports trends from timestamped `nvme smart-log` JSON snapshots:

```sh
nvme-health-report /path/to/snapshots
```

Snapshots must use UTC filenames in the form `YYYY-MM-DDTHH-MM-SSZ.json`. The
source directory may be local or mounted; transport is outside the command. Run
`nvme-health-report --help` for the input contract, columns, and marker
semantics.
