# Hyprland Dotfiles

Dotfiles for Hyprland/Wayland desktop on **Fedora** and **Arch Linux**, managed with [chezmoi](https://chezmoi.io). Features automated installation with collision detection, Material You theming, and development environment setup.

## Features

- **Dynamic Theme System** - Material You colors from wallpapers via matugen
- **Automated Installation** - Registry-based packages with collision detection and state tracking
- **Profile Support** - Separate configs for work and personal machines
- **Hyprland Desktop** - Wayland compositor with waybar, wofi, swaync
- **Dev Environment** - Neovim, wezterm, fish shell, oh-my-posh

## Quick Start

```bash
# Install chezmoi and apply dotfiles
sh -c "$(curl -fsLS get.chezmoi.io)"
chezmoi init --apply https://github.com/MasonRhodesDev/dotfiles.git

# Optional: Enable auto-sync daemon
systemctl --user enable --now chezmoi-daemon.timer
```

Installation happens automatically after dotfiles are applied:
1. System packages (requires sudo)
2. User packages (no sudo)
3. Profile-specific packages (work/personal)

## Structure

```
.
├── .chezmoiscripts/          # Run-once/run-on-change scripts
├── dot_config/               # Application configs
│   ├── hypr/                # Hyprland
│   ├── nvim/                # Neovim
│   ├── waybar/              # Status bar
│   └── ...
├── dot_local/share/
│   └── chezmoi-libs/        # Installation libraries
├── scripts/
│   └── hyprland-theme-toggle/  # Theme system
├── software_installers/
│   └── packages.toml        # Package registry
├── run_after_*.sh.tmpl      # Post-apply installers
└── tests/                   # Docker-based tests
```

## Installation System

Packages are defined in `software_installers/packages.toml`:

```toml
[common.hyprland]
description = "Hyprland compositor"
install_level = "system"

  [common.hyprland.fedora]
  packages = ["hyprland", "waybar"]
  repos = ["copr:solopasha/hyprland"]

  [common.hyprland.arch]
  packages = ["hyprland", "waybar"]
  aur_packages = ["hyprlock-git"]
```

**Features:**
- Collision detection (prevents dnf/cargo/flatpak/AUR conflicts)
- State tracking (idempotent, resumable)
- Profile-based (work vs personal)
- Error isolation (failures don't block dotfiles)

**State database:** `~/.local/state/chezmoi-installs/state.db.json`

## Profiles

Auto-detected by hostname:
- `mason-work` → work profile
- Everything else → personal profile

Configure optional packages in `~/.config/chezmoi/chezmoi.toml`:
```toml
[data.profile]
    type = "work"
    optional_packages = ["python_dev", "java_dev"]
```

## Theme System

```bash
# Toggle light/dark theme
~/scripts/hyprland-theme-toggle/executable_theme-toggle-modular.sh dark

# Restore saved theme
~/scripts/hyprland-theme-toggle/theme-restore.sh
```

Themes apply to: Hyprland, GTK, Qt, waybar, wezterm, neovim, swaync, wofi

## Common Tasks

**Add new file:**
```bash
chezmoi add ~/.config/newapp/config.conf
```

**Check status:**
```bash
chezmoi status
chezmoi diff
```

**Add new package:**
Edit `software_installers/packages.toml`, then run `chezmoi apply`

**View installation state:**
```bash
cat ~/.local/state/chezmoi-installs/state.db.json | jq '.phases'
```

**Re-run installers:**
```bash
cd ~/.local/share/chezmoi
./run_after_10-system-packages.sh
./run_after_20-user-packages.sh
```

## Testing

```bash
# Run all tests (Fedora + Arch in Docker)
./tests/run-tests.sh

# Run specific distro
./tests/run-tests.sh fedora
./tests/run-tests.sh arch
```

## Troubleshooting

**Installation failed:**
```bash
# Check logs
tail ~/.local/state/chezmoi-installs/install.log

# Check state
cat ~/.local/state/chezmoi-installs/state.db.json | jq '.phases.system.categories'

# Remove lock if stuck
rm ~/.local/state/chezmoi-installs/install.lock
```

**Theme not working:**
```bash
command -v matugen
~/scripts/hyprland-theme-toggle/executable_theme-toggle-modular.sh
```

**Reset everything:**
```bash
rm ~/.local/state/chezmoi-installs/state.db.json
chezmoi apply
```

## Documentation

- [docs/SOFTWARE-INSTALLERS.md](docs/SOFTWARE-INSTALLERS.md) - Installation system details
- [docs/THEME-SYSTEM.md](docs/THEME-SYSTEM.md) - Theme management
- [docs/HYPRLAND-CONFIG.md](docs/HYPRLAND-CONFIG.md) - Compositor setup
- [docs/NEOVIM-SETUP.md](docs/NEOVIM-SETUP.md) - Editor config
- [docs/CHEZMOI-WORKFLOW.md](docs/CHEZMOI-WORKFLOW.md) - Dotfile workflow
- [software_installers/CLAUDE.md](software_installers/CLAUDE.md) - Installer architecture
