---
name: maintain-brewfile
description: Maintain this repository's Homebrew Brewfile. Use whenever Brewfile is discussed, edited, reviewed, sorted, curated, or verified, including package additions/removals, taps, casks, font casks, Homebrew Bundle checks, and generated dump comparison.
---

# Maintain Brewfile

## Purpose

Keep `Brewfile` as a curated development workstation manifest, not a full
machine snapshot. Prefer explicit, reviewable edits over replacing it with
`brew bundle dump` output.

## File Shape

Use this section order:

1. `# Taps`
2. `brew` entries
3. non-font `cask` entries
4. `# Fonts`

Sort entries alphabetically within each section by package name.

Taps and font casks are compact inventory sections: do not add individual
description comments above their entries.

For `brew` entries and non-font `cask` entries, keep useful one-line description
comments when they already exist or when adding a new entry whose purpose is not
obvious.

Do not add a separate generated-file banner. The file is hand-curated.

## Curation Rules

Keep the Brewfile focused on development, terminal, shell, agent, dotfiles,
language-tooling, and generic command-line utilities.

Do not add broad GUI app inventory just because it is installed locally. Casks
belong here only when they are part of the development or agent workflow.

Do not add tools managed by the repository's language/runtime manager unless the
user explicitly wants Homebrew to own them. For example, if a runtime is managed
through project toolchain pins, do not also add it as a top-level Homebrew
formula.

Treat `tap` entries as resolver state. Keep a tap only when at least one
remaining Brewfile entry needs it.

Formula dependencies are not normally top-level entries. If `brew deps` shows a
tool is only required by another formula, do not add it as a separate `brew`
entry unless the user wants to install that tool directly.

## Homebrew Bundle Notes

`brew bundle dump` is useful for discovery and comparison, but it is not the
formatting source of truth for this file. It may include local apps, package
manager state, and entries outside the curated scope.

Homebrew Bundle can manage more than formulae and casks. If `cargo`, `npm`,
`go`, `uv`, or similar entries appear, remember that Brew Bundle delegates those
installs to the relevant package manager; they are not Homebrew formula
dependencies.

`brew bundle check --file Brewfile --verbose` reports both missing and outdated
dependencies. For casks, an installed-but-outdated app can still make the check
fail. Verify with `brew outdated --cask --greedy` before changing the Brewfile
to fix that kind of failure.

## Workflow

Before editing:

```sh
git status --short --branch
sed -n '1,220p' Brewfile
```

When comparing against local installed state, use temporary files under
`./tmp/`:

```sh
brew bundle dump --file tmp/Brewfile.current --force
```

Inspect the dump as input only. Do not overwrite the curated `Brewfile` with it.

Useful checks:

```sh
brew leaves --installed-on-request | sort
brew leaves | sort
brew list --formula --versions <name>
brew list --cask --versions <name>
brew deps --formula --tree <name>
```

For third-party taps, `brew info` and `brew search` may refuse to load formulae
from untrusted taps. Do not run `brew trust` unless the user explicitly asks. If
a read-only name check is enough, inspect the local tap checkout:

```sh
brew --repository <owner>/<tap>
find "$(brew --repository <owner>/<tap>)" -maxdepth 3 -type f
```

## Verification

After editing, run:

```sh
dprint check
brew bundle check --file Brewfile --verbose
```

Report the command and exit status. If `brew bundle check` fails because a
declared package is intentionally not installed yet, say that directly and name
the missing entry.
