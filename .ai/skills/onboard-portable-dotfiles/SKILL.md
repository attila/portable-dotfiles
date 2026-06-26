---
name: onboard-portable-dotfiles
description: Guide a user through adopting this portable-dotfiles repository. Use when asked how to install, set up, choose modules, configure nono profiles, prepare agent CLI sandboxes, configure shell/Git/GPG/Homebrew, or adapt the dotfiles to a new machine.
---

# Onboard Portable Dotfiles

## Purpose

Guide a user through adopting this repository selectively. Do not assume they
want every module or every agent workflow.

## First Step

Start by identifying what the user wants to set up:

- shell only;
- terminal and shell;
- Git and development tools;
- agent instruction files;
- nono sandbox profiles;
- full development baseline.

Recommend the smallest module set that satisfies that goal.

## Instruction Conflicts

Follow the user's active agent instructions and local policy. Do not act
directly against directives already present in the user's agent or repository.

If this skill conflicts with a higher-priority instruction, highlight the
contradiction before acting:

- name the conflicting instructions;
- explain the practical effect;
- proceed only within the higher-priority constraint.

## Module Guidance

Explain module consequences before recommending `stow`:

- `zsh`: shell startup, PATH, plugins, prompt integration, and nono helper PATH
  wiring.
- `git`: ignore defaults and commit message template.
- `ghostty`: terminal settings.
- `tmux`: terminal multiplexer settings.
- `starship`: prompt configuration.
- `agents`: shared repository-local agent instructions.
- `codex`: Codex instruction link.
- `claude`: Claude Code instruction link.
- `nono`: sandbox profiles plus helper scripts, including the Node proxy shim.

Use `stow -n <module>` as a dry-run before applying a module. Use
`stow <module>` to install it, `stow -D <module>` to remove it, and
`stow -R <module>` after local edits.

## nono Onboarding

When the user wants nono profiles:

1. Confirm nono is installed.
2. Ask which agent CLIs they use: Codex, Claude Code, Crush, or another tool.
3. Recommend only the matching profiles.
4. Explain profile inheritance before changing grants.
5. Tell the user to adapt machine-local placeholders such as `/Users/username`
   where exact macOS seatbelt paths are required.
6. Configure Git identity and GPG signing outside the sandbox before relying on
   signed commits inside it.
7. Store API keys in nono's credential store or the OS secret store. Do not put
   real tokens in profile JSON.
8. Use profile `network.credentials`, `network.custom_credentials`, or
   `env_credentials` only after the credential source and intended injection
   path are clear.
9. Stow `zsh` when the Node proxy shim should be active. The zsh PATH wiring is
   part of the nono helper contract.
10. Run the helper smoke test after stowing `nono` or changing zsh PATH wiring:

    ```sh
    nono/.local/share/nono-helpers/smoke-test.sh
    ```

## Verification

Prefer checks that prove the selected setup, not broad unrelated validation:

```sh
brew bundle check --file Brewfile --verbose
stow -n <module>
dprint check
nono/.local/share/nono-helpers/smoke-test.sh
```

For agent profiles, run a profile smoke test only after the user picks the agent
and command. Do not invent profile names or credential names.

## Do Not

- Do not publish, push, or modify external systems.
- Do not edit secrets or ask the user to place real tokens in tracked files.
- Do not recommend stowing every module by default.
- Do not assume macOS only.
- Do not assume all users want agent sandboxes.
- Do not blindly copy profiles without reviewing grants.
- Do not override the user's existing agent or repository instructions.
