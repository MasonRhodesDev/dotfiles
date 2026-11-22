# Dotfiles

One Nix flake in `nix/` configures every machine: home-manager on Linux
(Fedora and Arch) and nix-darwin with home-manager on macOS. README.md
describes the layout and the `dot` commands.

## Key Commands

Nix is on PATH only in a login shell (`bash -lc`).

- `nix/dot --private stub --machine <stub> show` shows a stub machine's traits and solutions
- `nix/dot --private stub --machine <stub> why <solution>` shows why a solution is enabled
- `nix flake check` (from `nix/`) builds every check and evaluates every stub machine
- `nix build .#lib.machines.<stub>.build` (from `nix/`) builds one machine's generation

Never run `dot switch` unless asked: it changes the machine you are on.

## Layout

- `nix/solutions/` holds the solutions, grouped by directory. Each says when it
  applies (`when` on traits), what it `requires` or `conflicts` with, and its
  `home`, `linux.home`, `linux.root`, `darwin.home` and `darwin.system` parts.
- `nix/traits.nix` lists the traits a machine states.
- `nix/lib/` loads the catalog, resolves each machine's solutions and composes
  its configuration.
- `nix/modules/home/` holds the options every home has: fragments, mutable
  files, root steps, services, credentials, and the chezmoi state retirement.
- `nix/checks/` and each solution's `checks` run in `nix flake check`.
- `nix/private-stub/` is a placeholder private input with stub machines.

## Rules

- This repo is PUBLIC. Personal values (names, emails, hostnames, addresses,
  hardware ids, accounts) live in the private input and reach code through
  `identity` or `machine.private`. The `leak-scan` check enforces it.
- No comments in any file. The `no-comments` check enforces it.
- A gitleaks pre-commit hook lives in `.githooks/`. Enable it in a clone with
  `git config core.hooksPath .githooks`. False positives go in `.gitleaks.toml`.

## greetd Config (external)

greetd configuration is owned by the packaged
https://github.com/MasonRhodesDev/greetd_game_mode setup flow, with
https://github.com/MasonRhodesDev/vigil as the greeter. Provision it with
`sudo game-mode setup`.
