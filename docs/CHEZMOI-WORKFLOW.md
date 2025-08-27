# Chezmoi Workflow Documentation

Complete guide to managing dotfiles with chezmoi, including templates, cross-machine synchronization, and best practices.

## Overview

This chezmoi setup provides:
- **Centralized dotfile management** - Single source of truth for all configurations
- **Cross-platform support** - Works on Fedora, Arch, and other Linux distributions
- **Template system** - Dynamic configurations based on machine-specific variables
- **Automatic synchronization** - Background daemon for real-time updates
- **Selective application** - Control which files are managed on each machine

## Core Concepts

### Source Directory

The chezmoi source directory contains all managed files:
```
~/.local/share/chezmoi/
├── dot_bashrc              # becomes ~/.bashrc
├── dot_config/             # becomes ~/.config/
├── scripts/                # becomes ~/scripts/
├── .chezmoi.toml.tmpl      # chezmoi configuration template
└── README.md               # this documentation
```

### File Naming Convention

Chezmoi uses prefixes to determine file handling:

| Prefix | Purpose | Example |
|--------|---------|---------|
| `dot_` | Hidden files/directories | `dot_bashrc` → `.bashrc` |
| `private_` | Restricted permissions (600) | `private_ssh_key` → `ssh_key` (mode 600) |
| `executable_` | Executable files | `executable_script.sh` → `script.sh` (mode 755) |
| `symlink_` | Symbolic links | `symlink_link` → creates symlink |
| `.tmpl` | Templates processed by chezmoi | `dot_gitconfig.tmpl` → `.gitconfig` |

## Basic Operations

### Daily Workflow

**Check status:**
```bash
# See what files have changed locally
chezmoi status

# See differences between source and target
chezmoi diff
```

**Update from repository:**
```bash
# Pull latest changes from git
chezmoi update

# Apply changes without updating from git
chezmoi apply
```

**Add new files:**
```bash
# Add a configuration file
chezmoi add ~/.config/newapp/config.conf

# Add an executable script
chezmoi add ~/scripts/new-script.sh

# Add multiple files
chezmoi add ~/.vimrc ~/.tmux.conf
```

**Edit configurations:**
```bash
# Edit file in source directory
chezmoi edit ~/.bashrc

# Edit and apply immediately
chezmoi edit --apply ~/.gitconfig
```

### Template System

Templates allow dynamic configuration based on machine properties:

**Template Variables:**
```toml
# .chezmoi.toml.tmpl
[data]
email = "{{ .email }}"
name = "{{ .name }}"
hostname = "{{ .chezmoi.hostname }}"
os = "{{ .chezmoi.os }}"
arch = "{{ .chezmoi.arch }}"

[data.git]
user = "{{ .name }}"
email = "{{ .email }}"
```

**Template Usage:**
```bash
# dot_gitconfig.tmpl
[user]
    name = {{ .git.user }}
    email = {{ .git.email }}

[core]
    editor = nvim

{{- if eq .chezmoi.hostname "work-laptop" }}
[url "git@github.com:company/"]
    insteadOf = https://github.com/company/
{{- end }}
```

**Test templates:**
```bash
# Preview template output
chezmoi execute-template < ~/.local/share/chezmoi/dot_gitconfig.tmpl

# Test specific template
chezmoi execute-template '{{ .chezmoi.hostname }}'
```

## Machine-Specific Configuration

### Initial Setup

**First-time setup:**
```bash
# Install chezmoi
sh -c "$(curl -fsLS get.chezmoi.io)"

# Initialize from repository
chezmoi init https://github.com/MasonRhodesDev/dotfiles.git

# Apply configurations
chezmoi apply
```

**Configure machine variables:**
```bash
# Edit chezmoi config
chezmoi edit-config

# Example ~/.config/chezmoi/chezmoi.toml
[data]
    email = "user@example.com"
    name = "Full Name"
    
[data.features]
    work = true
    personal = false
```

### Conditional Configuration

**OS-specific templates:**
```bash
# dot_bashrc.tmpl
export PATH="$PATH:$HOME/.local/bin"

{{- if eq .chezmoi.os "darwin" }}
# macOS-specific settings
export PATH="/opt/homebrew/bin:$PATH"
{{- else if eq .chezmoi.os "linux" }}
# Linux-specific settings
export PATH="/usr/local/bin:$PATH"
{{- end }}

{{- if .features.work }}
# Work-specific aliases
alias vpn="sudo openvpn /etc/openvpn/work.conf"
{{- end }}
```

**Hostname-based configuration:**
```bash
# dot_config/waybar/config.tmpl
{
    "layer": "top",
    "position": "top",
    {{- if eq .chezmoi.hostname "desktop" }}
    "height": 30,
    "modules-left": ["hyprland/workspaces", "cpu", "memory"],
    {{- else if eq .chezmoi.hostname "laptop" }}
    "height": 24,
    "modules-left": ["hyprland/workspaces", "battery"],
    {{- end }}
    "modules-right": ["clock"]
}
```

## Advanced Features

### Scripts and Hooks

**Run scripts before/after operations:**

```bash
# .chezmoiscripts/run_before_apply.sh
#!/bin/bash
echo "Backing up important configs..."
cp ~/.config/important.conf ~/.config/important.conf.backup

# .chezmoiscripts/run_after_apply.sh  
#!/bin/bash
echo "Reloading configurations..."
systemctl --user reload waybar
```

**Conditional scripts:**
```bash
# .chezmoiscripts/run_once_install_packages.sh.tmpl
#!/bin/bash
{{- if eq .chezmoi.os "linux" }}
{{-   if eq .chezmoi.osRelease.id "fedora" }}
sudo dnf install -y package1 package2
{{-   else if eq .chezmoi.osRelease.id "arch" }}
sudo pacman -S --noconfirm package1 package2
{{-   end }}
{{- end }}
```

### External Data Sources

**Use external commands in templates:**
```bash
# Get current theme from system
{{- $theme := output "gsettings" "get" "org.gnome.desktop.interface" "color-scheme" | trim -}}

[appearance]
theme = "{{ $theme }}"
```

**Read from files:**
```bash
# dot_config/app/config.tmpl
{{- $colors := include "~/.config/matugen/colors.json" | fromJson -}}
background = "{{ $colors.colors.background }}"
foreground = "{{ $colors.colors.on_background }}"
```

## Daemon and Automation

### Chezmoi Daemon Setup

The system includes a daemon for automatic synchronization:

**Systemd service configuration:**
```ini
# ~/.config/systemd/user/chezmoi-daemon.service
[Unit]
Description=Chezmoi automatic synchronization daemon
After=network-online.target

[Service]
Type=simple
ExecStart=/home/mason/scripts/chezmoi-daemon.sh
Restart=always
RestartSec=30

[Install]
WantedBy=default.target
```

**Timer for periodic updates:**
```ini
# ~/.config/systemd/user/chezmoi-daemon.timer
[Unit]
Description=Run chezmoi daemon every 5 minutes
Requires=chezmoi-daemon.service

[Timer]
OnCalendar=*:0/5
Persistent=true

[Install]
WantedBy=timers.target
```

**Daemon script:**
```bash
#!/bin/bash
# scripts/chezmoi-daemon.sh

while true; do
    # Check for remote changes
    if chezmoi git -- fetch origin main; then
        # Check if updates available
        if ! chezmoi git -- diff --quiet HEAD origin/main; then
            echo "Updates available, pulling changes..."
            chezmoi update
            
            # Notify user
            notify-send "Dotfiles Updated" "Configurations have been synchronized"
        fi
    fi
    
    # Sleep for 5 minutes
    sleep 300
done
```

### File Watching

**Watch for local changes:**
```bash
# scripts/chezmoi-trigger.sh
#!/bin/bash

# Watch configuration directories
inotifywait -mr --events modify,create,delete \
    ~/.config/hypr/ \
    ~/.config/waybar/ \
    ~/.config/nvim/ | while read path event file; do
    
    echo "Change detected: $path$file ($event)"
    
    # Add changed file to chezmoi
    if [[ -f "$path$file" ]]; then
        chezmoi add "$path$file"
        echo "Added $path$file to chezmoi"
    fi
done
```

## Multi-Machine Management

### Machine Profiles

**Define machine-specific features:**
```toml
# ~/.config/chezmoi/chezmoi.toml

[data]
    hostname = "{{ .chezmoi.hostname }}"
    
[data.profiles]
    desktop = {{ eq .chezmoi.hostname "desktop-pc" }}
    laptop = {{ eq .chezmoi.hostname "laptop" }}
    work = {{ eq .chezmoi.hostname "work-laptop" }}

[data.features]
    gaming = {{ .profiles.desktop }}
    battery = {{ .profiles.laptop }}
    vpn = {{ .profiles.work }}
```

**Profile-based configuration:**
```bash
# dot_config/hypr/hyprland.conf.tmpl
{{- if .profiles.laptop }}
# Laptop-specific settings
bind = , XF86MonBrightnessUp, exec, brightnessctl set +10%
bind = , XF86MonBrightnessDown, exec, brightnessctl set 10%-
{{- end }}

{{- if .profiles.desktop }}
# Desktop-specific settings
monitor = DP-3, 2560x1440@144, 0x0, 1
monitor = HDMI-A-1, 1920x1080@60, 2560x0, 1
{{- end }}
```

### Synchronization Strategies

**Selective file application:**
```bash
# Apply only specific files
chezmoi apply ~/.bashrc ~/.gitconfig

# Apply files matching pattern  
chezmoi apply ~/.config/nvim/

# Dry run to see what would be applied
chezmoi apply --dry-run
```

**Branch-based management:**
```bash
# Use different branches for different machines
chezmoi init --branch laptop https://github.com/user/dotfiles.git

# Switch branches
chezmoi git -- checkout desktop
chezmoi apply
```

## Backup and Recovery

### Backup Strategies

**Manual backup:**
```bash
# Create backup before major changes
chezmoi archive | gzip > ~/dotfiles-backup-$(date +%Y%m%d).tar.gz

# Backup specific files
tar czf ~/.config-backup.tar.gz ~/.config/
```

**Automated backup:**
```bash
#!/bin/bash
# .chezmoiscripts/run_before_apply.sh

BACKUP_DIR="$HOME/.dotfile-backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

# Backup files that will be changed
chezmoi status --format json | jq -r '.[] | select(.status != "ok") | .target' | while read file; do
    if [[ -f "$file" ]]; then
        backup_path="$BACKUP_DIR/$(basename "$file")_$TIMESTAMP"
        cp "$file" "$backup_path"
        echo "Backed up $file to $backup_path"
    fi
done
```

### Recovery Procedures

**Restore from backup:**
```bash
# Restore specific file
cp ~/.dotfile-backups/bashrc_20240101_120000 ~/.bashrc

# Restore from chezmoi archive
tar xzf dotfiles-backup-20240101.tar.gz -C /tmp/restore
chezmoi apply --source /tmp/restore
```

**Reset to repository state:**
```bash
# WARNING: This will overwrite local changes
chezmoi apply --force

# Reset specific file
chezmoi forget ~/.bashrc
chezmoi add ~/.bashrc
```

## Troubleshooting

### Common Issues

**Template execution errors:**
```bash
# Debug template processing
chezmoi execute-template --debug < template.tmpl

# Check template variables
chezmoi data
```

**File permission issues:**
```bash
# Fix file permissions
chezmoi apply --force

# Check file attributes
chezmoi status --format detailed
```

**Synchronization conflicts:**
```bash
# See what changed locally
chezmoi diff

# See what changed remotely
chezmoi git -- diff HEAD origin/main

# Resolve conflicts manually
chezmoi merge-all
```

### Debugging Commands

**Verbose output:**
```bash
# Verbose chezmoi operations
chezmoi --verbose apply

# Debug mode
chezmoi --debug status
```

**Configuration validation:**
```bash
# Check chezmoi configuration
chezmoi doctor

# Validate templates
chezmoi execute-template --init < .chezmoi.toml.tmpl
```

## Best Practices

### Organization

1. **Use modular templates** - Break complex configs into includes
2. **Group related files** - Keep similar configs in subdirectories  
3. **Document changes** - Use git commit messages to explain modifications
4. **Test templates** - Always test template execution before applying

### Security

1. **Use private_ prefix** - For files containing sensitive data
2. **Template secrets** - Use external password managers
3. **Exclude sensitive files** - Add to .chezmoiignore if needed
4. **Review diffs** - Always check changes before applying

### Performance

1. **Lazy loading** - Use conditional templates to skip unnecessary processing
2. **Cache external data** - Store frequently accessed data in variables
3. **Optimize scripts** - Make run scripts idempotent and fast
4. **Selective sync** - Only sync needed files on each machine

### Maintenance

1. **Regular updates** - Keep chezmoi and templates up to date
2. **Clean unused files** - Remove obsolete configurations
3. **Backup before changes** - Always have recovery options
4. **Test on clean systems** - Validate complete setup process

---

This chezmoi workflow provides powerful dotfile management with flexibility for complex, multi-machine environments while maintaining simplicity for daily operations.