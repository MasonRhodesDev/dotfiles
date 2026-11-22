# Dotfiles

One Nix flake configures every machine: home-manager on Linux (Fedora and
Arch, a Hyprland desktop or a headless server) and nix-darwin with
home-manager on macOS. The flake lives in [`nix/`](nix).

## How it is put together

- **Solutions** (`nix/solutions/<group>/.../<solution>`) each configure one
  thing: a shell, an editor, a service, a piece of hardware. A solution has a
  `home` part and may add `linux.home`, `linux.root`, `darwin.home` or
  `darwin.system` parts, plus `checks` the flake runs.
- **Traits** (`nix/traits.nix`) describe a machine: `headless`, `form`,
  `profile`, `secrets`, `uses` and `hardware`. A solution or group says when it
  applies with `when`, and `requires` or `conflicts` with other solutions.
- **Machines** are data in a private input, never in this repo. The input holds
  `identity.nix` and one `machines/<name>.nix` per machine with its system,
  traits, user and private values. [`nix/private-stub`](nix/private-stub) shows
  the shape with placeholder values, and the flake checks build against it.
- **Root steps** (`linux.root`) are what a Linux home cannot do for itself:
  distro packages, files under `/etc`, units. `dot switch` runs them with
  `sudo` before it activates the home generation, whenever they changed.

## Set up a machine

On a fresh machine with only `curl`:

```bash
curl -fsSL <raw URL of nix/bootstrap> -o bootstrap
sh bootstrap <repo URL>
```

`nix/bootstrap` installs Determinate Nix when it is missing, signs in to
GitHub for an SSH key, clones the repo to `$DOTFILES_DIR` (default
`~/.local/share/dotfiles`) and runs `nix/dot switch`.

`dot` finds the private input beside the checkout's origin (`<origin>-private`)
unless `--private REF` or `DOTFILES_PRIVATE` names one, and picks the machine
entry named after the host unless `--machine NAME` or `DOTFILES_MACHINE` does.
For a machine with no entry it prints the entry to add and the traits to
choose from.

## Everyday commands

Run them from the checkout's `nix/` directory, or put `nix/dot` on your PATH.

```bash
dot plan                 # what a switch would move, start and stop (Linux)
dot switch               # build and activate this machine
dot show                 # traits, solutions and started units of this machine
dot why <solution>       # which traits enabled a solution here
dot secrets              # the credentials this machine needs, and where each comes from
dot check                # nix flake check
dot --private stub --machine stub-work-laptop show   # try it with the stub input
```

`--build-host HOST` builds on another machine over SSH and copies the result
back.

## Working on the flake

- Add a solution as a `.nix` file, or a directory with a `default.nix`, under
  the group it belongs to. The catalog finds it by path and rejects unknown
  keys.
- Personal values (hostnames, addresses, accounts, hardware ids) go in the
  private input and reach a solution through `machine.private` or `identity`.
  Committed defaults are generic. The `leak-scan` check fails on any term the
  private identity lists in `leakTerms`.
- Files carry no comments. The `no-comments` check enforces it.
- `nix flake check` builds every check and evaluates every stub machine.

## Secrets

Credentials resolve through one chain: the machine's local store, then the
provider its `secrets` trait names (Infisical, Bitwarden Secrets Manager or a
Bitwarden vault), then a derived value, then a manual step. `dot secrets`
lists what a machine needs. Nothing secret is committed.

The repo is public. Enable the pre-commit hook in a clone with
`git config core.hooksPath .githooks`. It runs gitleaks, and on a work machine
also checks a private blocklist. False positives go in `.gitleaks.toml`.

## Desktop

The desktop environment (Hyprland config, waybar, swaync, fuzzel, theming
templates, idle and lock policy) ships as the
[hypr-DE](https://github.com/MasonRhodesDev/hypr-DE) package. This flake
installs it and owns the per-machine layer on top, described in
[docs/HYPRLAND-CONFIG.md](docs/HYPRLAND-CONFIG.md). Theming is
[lmtt](https://github.com/MasonRhodesDev/linux-multi-theme-toggle), see
[docs/THEME-SYSTEM.md](docs/THEME-SYSTEM.md). The editor setup is in
[docs/NEOVIM-SETUP.md](docs/NEOVIM-SETUP.md).

The login stack is owned by
[greetd_game_mode](https://github.com/MasonRhodesDev/greetd_game_mode) with
[Vigil](https://github.com/MasonRhodesDev/vigil) as its greeter. Provision it
with `sudo game-mode setup`.

## Coming from chezmoi

This repo was a chezmoi source tree until the flake replaced it. The first
`dot switch` on a machine that chezmoi managed moves the files chezmoi wrote to
`~/.local/state/dotfiles/chezmoi-retired`. The switch after that removes
chezmoi's own state (`~/.local/share/chezmoi`, `~/.config/chezmoi`, its cache
and drift state). It keeps the source checkout, and says why, when the checkout
has uncommitted, untracked, stashed or unpushed work, linked worktrees, or a
copy of this flake. The chezmoi binary itself came from the distro, so remove
it with the package manager.

## License

MIT License.
