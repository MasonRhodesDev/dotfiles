# dotfiles

One Nix flake configures a set of machines, with home-manager on Linux distros (not NixOS) and nix-darwin on macOS. Every piece of configuration is a solution that says which machines it is for. The machines themselves live in a separate private repository, so this one holds no personal data.

## Layout

| Path | What it holds |
|------|---------------|
| `traits.nix` | The traits a machine states, each with a fixed set of values: `headless`, `form`, `profile`, `secrets`, `uses`, `hardware`. |
| `solutions/` | The solutions, in groups. A group is a directory with a `_group.nix`, and the top level holds groups only. |
| `lib/` | Resolves a machine's traits to the solutions it gets, and composes them into one home-manager or nix-darwin configuration. |
| `modules/` | Shared modules the solutions build on, for files an app also writes, root steps, credentials, services and reports. |
| `checks/` | The flake checks. `nix flake check` runs them. |
| `private-stub/` | An example private repository. It is the default of the `private` input. |
| `dot` | The command that builds and switches a machine. |
| `bootstrap` | Sets up a fresh machine and runs its first switch. |

## Solutions

A solution is a `.nix` file, or a directory with a `default.nix`, whose name is its id. It sets `name`, `description` and `platforms` (`linux`, `darwin` or both), and puts its configuration in one or more slots:

| Slot | Is |
|------|----|
| `home` | a home-manager module for every platform |
| `linux.home`, `darwin.home` | a home-manager module for one platform |
| `linux.root` | a step that needs root on a Linux distro, such as files under `/etc`, system units or distro packages |
| `darwin.system` | a nix-darwin module |

`when` limits a solution, or a whole group, to machines whose traits match, as in `when = { headless = false; uses = "gaming"; }`. `requires` and `conflicts` name other solutions, and `checks` adds flake checks. A switch runs the root steps with sudo, and only when they changed since the last run.

## Declaring a machine

The private repository has this shape:

```
identity.nix
machines/
  <machine>.nix
```

`identity.nix` holds what every machine shares: the name and email addresses for git, the git `includeIf` rules, and `leakTerms`, the names and hosts the leak scan must never find in this repository. `private-stub/identity.nix` is an example.

A machine entry is named for the machine's short hostname (its LocalHostName on macOS):

```nix
{
  system = "x86_64-linux";
  traits = { headless = false; form = "laptop"; profile = "personal"; secrets = "none"; uses = [ "dev" ]; };
  user = { name = "alex"; home = "/home/alex"; };
  private = { };
}
```

`system` is `x86_64-linux`, `aarch64-linux` or `aarch64-darwin`. `private` holds values that belong to this machine alone, such as monitor names, which some solutions read. `exclude` drops solutions or whole groups by id, and `include` names solutions the machine must get, so evaluation fails when its traits rule one out. The machines in `private-stub/machines/` use every trait value between them, and a check keeps it so.

To start your own, copy `private-stub` into a new repository named like this one with `-private` on the end, next to it on the same host, and edit it.

## Setting up a machine

```sh
git clone <your fork> ~/.local/share/dotfiles-flake
sh ~/.local/share/dotfiles-flake/bootstrap
```

The bootstrap installs Nix if it is missing, signs in to GitHub with an SSH key so the private repository can be fetched, and runs `dot switch`. Run from elsewhere, `sh bootstrap <repo url>` clones the repository to `$DOTFILES_DIR` (default `~/.local/share/dotfiles-flake`) first.

## dot

```sh
./dot [--machine NAME] [--private REF] [--build-host HOST] [COMMAND]
```

| Command | Does |
|---------|------|
| `switch` | Builds the machine and activates it. The default. |
| `plan` | On Linux, lists the files a switch would set aside, the units it would stop and whether it would run the root steps. Changes nothing. |
| `build` | Builds the machine and prints the store path. |
| `show` | Prints the machine's traits, the solutions it gets and what it starts. |
| `why ID` | Prints the traits and `when` conditions that gave the machine solution `ID`. |
| `secrets` | Lists the credentials the machine's solutions expect and whether each one resolves. `--json` for JSON, `--machine NAME` to list another machine's without checking. |
| `check` | Runs `nix flake check` with the private repository. |

`--machine` defaults to the short hostname. `--private` takes any flake reference, and `--private stub` uses `private-stub`. Without it, dot derives the private repository from the checkout's `origin`, so `git@github.com:you/dotfiles.git` gives `git+ssh://git@github.com/you/dotfiles-private`. `--build-host` evaluates and builds on another machine over SSH and copies only the result back, and `--build-host local` builds here even when the active generation names a build host. `DOTFILES_MACHINE`, `DOTFILES_PRIVATE` and `DOTFILES_BUILD_HOST` set the same three, and `DOTFILES_FLAKE` points dot at another checkout.

Without a private repository, try it on the stub machines:

```sh
./dot --private stub --machine stub-headless show
nix flake check
```

## Development

`nix flake check` builds every check against `private-stub`. Among them, `no-comments` fails on any comment in the tree, and `leak-scan` fails on home directories, private addresses, email addresses and the `leakTerms` of the private input. Run it with yours as well:

```sh
nix build .#checks.x86_64-linux.leak-scan --override-input private <your private repo>
```

`git config core.hooksPath .githooks` turns on the pre-commit hook, which runs gitleaks on staged changes.

## License

MIT
