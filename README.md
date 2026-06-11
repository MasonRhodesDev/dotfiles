# Hyprland Dotfiles

Dotfiles for a Hyprland/Wayland desktop on **Fedora** (with Arch support),
managed with [chezmoi](https://chezmoi.io). Work/personal machine split via
template conditionals, Material You theming via
[lmtt](https://github.com/MasonRhodesDev/linux-multi-theme-toggle), and a
declarative package registry audited by Claude.

## 🚀 Quick Start

### Fresh Installation

```bash
# Install chezmoi
sh -c "$(curl -fsLS get.chezmoi.io)"

# Initialize and apply dotfiles (run_once scripts handle setup: fonts,
# shell, jq, hyprstate, etc.)
chezmoi init --apply https://github.com/MasonRhodesDev/dotfiles.git
```

### Existing Machine

```bash
# Pull latest changes
chezmoi update

# Check for differences
chezmoi diff

# Apply changes
chezmoi apply
```

## 📁 Repository Structure

```
.
├── dot_config/              # ~/.config applications
│   ├── hypr/               # Hyprland compositor config
│   ├── hypr/profiles/      # Monitor profiles consumed by hyprstate
│   ├── nvim/               # Neovim configuration
│   ├── waybar/             # Status bar configuration
│   ├── matugen/            # Theme generation templates
│   └── ...
├── dot_local/bin/          # Local executables
├── scripts/                # Utility scripts (deployed to ~/scripts)
├── software_installers/    # packages.toml registry (repo-only, see docs)
├── .chezmoiscripts/        # run_once / run_onchange lifecycle scripts
└── docs/                   # Detailed documentation (repo-only)
```

## 🎨 Theme System

Theming is handled by [lmtt](https://github.com/MasonRhodesDev/linux-multi-theme-toggle)
(Linux Multi-Theme Toggle), a standalone tool that generates Material You
colors with matugen and injects them into application configs:

```bash
lmtt switch light|dark|toggle   # Switch themes
lmtt status                     # Current theme
lmtt list                       # Installed modules
```

Generated files are prefixed `lmtt-*` and excluded from chezmoi via
`.chezmoiignore`.

## 💻 Key Applications

| Category | Application | Config Location |
|----------|-------------|-----------------|
| **Compositor** | Hyprland | `~/.config/hypr/` |
| **Terminal** | Wezterm | `~/.config/wezterm/` |
| **Editor** | Neovim / Zed | `~/.config/nvim/`, `~/.config/zed/` |
| **Shell** | Fish + Oh My Posh | `~/.config/fish/` |
| **Status Bar** | Waybar | `~/.config/waybar/` |
| **Launcher** | Fuzzel | `~/.config/fuzzel/` |
| **Notifications** | SwayNC | `~/.config/swaync/` |
| **System Monitor** | Btop | `~/.config/btop/` |

## 🔧 Common Tasks

### Adding New Files
```bash
# Add a config file to chezmoi
chezmoi add ~/.config/newapp/config.conf

# Add a script
chezmoi add ~/scripts/my-script.sh
```

### Managing Templates
```bash
# Test template rendering
chezmoi execute-template < ~/.local/share/chezmoi/dot_config/example.tmpl

# Edit templates
chezmoi edit ~/.gitconfig
```

### Monitoring Changes
```bash
# Check chezmoi status
chezmoi status

# See what would be applied
chezmoi diff
```

## 📚 Documentation

- [Software Package Registry](docs/SOFTWARE-INSTALLERS.md)
- [Theme System](docs/THEME-SYSTEM.md)
- [Hyprland Configuration](docs/HYPRLAND-CONFIG.md)
- [Neovim Setup](docs/NEOVIM-SETUP.md)
- [Chezmoi Workflow](docs/CHEZMOI-WORKFLOW.md)

## greetd Login Manager

The greetd configuration has been extracted to its own standalone repo:

**[MasonRhodesDev/greetd-config](https://github.com/MasonRhodesDev/greetd-config)** — cloned to `/opt/greetd-config`

```bash
# First install
sudo /opt/greetd-config/install.sh

# Update (uses saved options)
sudo /opt/greetd-config/install.sh --update
```

Static config files are symlinked from the repo into `/etc/greetd/`, so edits in `/opt/greetd-config/` take effect immediately without re-running the installer.

## ⚠️ Important Notes

- **Never use `chezmoi apply --force`** - This can overwrite local changes
- **Use `chezmoi add` to save changes** - Don't edit deployed-file copies in `.local/share/chezmoi` directly
- **Work/personal split** - `is_work` (hostname-based) gates work-only files (Claude templates) and excludes gaming/Steam configs from work machines via `.chezmoiignore`

## 📄 License

MIT License.
