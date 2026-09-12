# AGENTS.md

Guidance for AI coding agents working in this repository.

## Repository shape

Each top-level directory is a `stow` module that maps onto `$HOME` when stowed,
so `zsh/.zshenv` becomes `~/.zshenv`. `tests` holds repository tests and is not
a module. Repo-local agent skills live under `.ai/skills/`.

## Delivery model

This repository uses trunk-based development. When the user explicitly asks for
a commit and a push, commit directly to `trunk`. Do not open a feature branch or
a pull request.

## Formatting

Every file is formatted by dprint. A pre-commit hook in `.githooks/pre-commit`
runs `dprint check` and blocks the commit when a file is unformatted. Activate
it once per clone:

```sh
git config core.hooksPath .githooks
```

Run `dprint fmt` before committing. Commit subjects follow Conventional Commits
and stay terse.
