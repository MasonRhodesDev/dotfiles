# Software Package Registry

The old numbered installer scripts (`executable_0X_*.sh`) were removed in
March 2026 (commit 18c0cd9). Package management is now a declarative
registry plus an LLM-driven audit — nothing here installs software
automatically.

## How it works

- **`software_installers/packages.toml`** — the single source of truth.
  Each entry declares a package group with a `profile` (`common` | `work` |
  `personal`), a `verify` shell command, install `priority`, and optional
  `github`/`website`/`depends_on`/`optional` fields. The directory is in
  `.chezmoiignore`, so it stays in the repo and is never deployed to `$HOME`.

- **`scripts/chezmoi-package-check.py`** (deployed to `~/scripts/`) — audits
  the live system against the manifest using the Claude CLI: it runs each
  entry's `verify` command, flags missing packages for the machine's profile,
  and detects installed-but-untracked drift. It can optionally open an
  interactive Claude session to update `packages.toml`.

- **`.chezmoiscripts/run_onchange_after_98-check-packages-with-claude.sh.tmpl`**
  — triggers the audit after `chezmoi apply` whenever the manifest's hash
  changes. Interactive-only (requires a TTY and user consent) with a cooldown
  to avoid spam.

## Installing something new

Install it however is appropriate for the OS (dnf, flatpak, cargo, source
build), then add an entry to `packages.toml` with a working `verify` command
so other machines know about it. Entries marked `optional = true` are skipped
gracefully when missing.

## Bootstrap on a new machine

`chezmoi init --apply` runs the `run_once` scripts (jq, fonts, fish shell,
hyprstate). Everything else is installed manually with `packages.toml` as the
checklist — or by letting the package-check audit walk through it.
