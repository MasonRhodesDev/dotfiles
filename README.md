# Hyprland Dotfiles

A comprehensive dotfiles repository for Hyprland/Wayland desktop environments on **Fedora** and **Arch Linux**, managed with [chezmoi](https://chezmoi.io). Features automated software installation, dynamic theme management with Material You colors, and a fully configured development environment.

## ✨ Features

- **🎨 Dynamic Theme System** - Material You color generation from wallpapers using matugen
- **🚀 Automated Setup** - Complete system installation from fresh Fedora install
- **⚙️ Hyprland Desktop** - Modern Wayland compositor with optimized keybindings
- **🔧 Development Ready** - Pre-configured Neovim, terminals, and development tools
- **📱 Modern UI** - waybar, hyprnotice notifications (custom Hyprland-native daemon), and more
- **🔄 Template System** - Dynamic configs with chezmoi templates

## 🚀 Quick Start

### Fresh Installation

```bash
# Install chezmoi
sh -c "$(curl -fsLS get.chezmoi.io)"

# Initialize and apply dotfiles
chezmoi init --apply https://github.com/MasonRhodesDev/dotfiles.git

# Run automated software installation
for script in ~/.local/share/chezmoi/software_installers/executable_*.sh; do
    [ -x "$script" ] && "$script"
done

# Enable chezmoi daemon for auto-sync
systemctl --user enable chezmoi-daemon.timer
systemctl --user start chezmoi-daemon.timer
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
├── chezmoi-daemon/           # Background sync service
├── dot_config/              # ~/.config applications
│   ├── hypr/               # Hyprland compositor config
│   ├── nvim/               # Neovim configuration
│   ├── waybar/             # Status bar configuration
│   ├── hypr/profiles/      # Monitor profiles consumed by hyprstate
│   ├── matugen/            # Theme generation templates
│   └── ...
├── dot_local/bin/          # Local executables
├── git_installers/         # Git-based software installers
├── scripts/                # Utility scripts
│   └── hyprland-theme-toggle/  # Modular theme system
├── software_installers/    # Automated installation scripts
└── docs/                   # Detailed documentation
```

## 🎨 Theme System

The modular theme system generates Material You colors from your wallpaper and applies them across all applications:

```bash
# Toggle between light/dark themes
~/scripts/hyprland-theme-toggle/executable_theme-toggle-modular.sh dark

# Restore saved theme
~/scripts/hyprland-theme-toggle/theme-restore.sh
```

**Supported Applications:**
- Hyprland (borders, window rules)
- GTK 3/4 applications
- Qt applications
- Waybar status bar
- Wezterm terminal
- Neovim editor
- SwayNC notifications
- Wofi launcher

See [docs/THEME-SYSTEM.md](docs/THEME-SYSTEM.md) for detailed documentation.

## 💻 Key Applications

| Category | Application | Config Location |
|----------|-------------|-----------------|
| **Compositor** | Hyprland | `~/.config/hypr/` |
| **Terminal** | Wezterm | `~/.wezterm.lua` |
| **Editor** | Neovim | `~/.config/nvim/` |
| **Shell** | Bash + Oh My Posh | `~/.bashrc`, `~/.bashrc.d/` |
| **Status Bar** | Waybar | `~/.config/waybar/` |
| **Launcher** | Wofi | `~/.config/wofi/` |
| **Notifications** | hyprnotice | `~/.config/hypr/hyprnotice.conf`, daemon at `~/repos/hyprnotice` |
| **File Manager** | Nautilus | GTK-themed |
| **System Monitor** | Btop | `~/.config/btop/` |

## ⚙️ System Requirements

- **OS**: Fedora Linux (40+) or Arch Linux (current)
- **Display**: Wayland-compatible graphics
- **Memory**: 8GB+ recommended for full desktop
- **Storage**: 10GB+ for all software

### Dependencies
- chezmoi (dotfile management)
- Git (version control)
- curl/wget (downloads)
- sudo access (system packages)
- **Arch users**: yay AUR helper (installed automatically)

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
chezmoi execute-template < ~/.local/share/chezmoi/dot_gitconfig.tmpl

# Edit templates
chezmoi edit ~/.gitconfig
```

### Theme Management
```bash
# Change wallpaper and update theme
matugen image path/to/wallpaper.jpg
~/scripts/hyprland-theme-toggle/executable_theme-toggle-modular.sh

# Manual theme application
~/scripts/hyprland-theme-toggle/modules/gtk.sh
```

### Monitoring Changes
```bash
# Check chezmoi status
chezmoi status

# See what would be applied
chezmoi diff

# Monitor real-time changes (daemon)
systemctl --user status chezmoi-daemon
```

## 📚 Documentation

- [Theme System Guide](docs/THEME-SYSTEM.md)
- [Software Installers](docs/SOFTWARE-INSTALLERS.md)
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

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test on a clean system
5. Submit a pull request

## ⚠️ Important Notes

- **Never use `chezmoi apply --force`** - This can overwrite local changes
- **Use `chezmoi add` to save changes** - Don't edit files in `.local/share/chezmoi` directly
- **Test theme changes carefully** - Some applications require restart
- **Backup important configs** - Before major updates

## 🐛 Troubleshooting

### Common Issues

**Theme not applying:**
```bash
# Check matugen installation
command -v matugen

# Verify template output
ls ~/.config/matugen/

# Re-run theme application
~/scripts/hyprland-theme-toggle/executable_theme-toggle-modular.sh
```

**Chezmoi sync issues:**
```bash
# Force refresh
chezmoi update --force

# Reset to repository state
chezmoi apply --force  # Use carefully!
```

**Software installation failures:**
```bash
# Check logs
ls ~/.software_installer_logs/

# Re-run specific installer
./software_installers/executable_03_hyprland.sh

# Arch users: Update yay and AUR packages
yay -Syu
```

## 📄 License

This repository is open source and available under the MIT License.

## 🙏 Acknowledgments

- [Hyprland](https://hyprland.org/) - Amazing Wayland compositor
- [chezmoi](https://chezmoi.io/) - Excellent dotfile manager
- [matugen](https://github.com/InioX/matugen) - Material You color generation
- [Oh My Posh](https://ohmyposh.dev/) - Beautiful shell prompts

---

**Made with ❤️ for the Linux desktop experience**