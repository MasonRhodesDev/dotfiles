# Chezmoi Daemon

A daemon system for monitoring dotfile changes and providing desktop notifications when chezmoi detects changes.

## Features

- **Automatic change detection**: Monitors for changes in your chezmoi dotfiles
- **Desktop notifications**: Uses `notify-send` to show change details
- **Multiple triggers**: Login autostart, hourly systemd timer, and manual triggers
- **Change deduplication**: Tracks hashes to avoid duplicate notifications
- **Comprehensive logging**: All activity logged to `~/.cache/chezmoi-daemon/daemon.log`

## Project Structure

```
chezmoi-daemon/
├── src/
│   ├── daemon.sh          # Main daemon script
│   └── trigger.sh         # Manual trigger script
├── systemd/
│   ├── chezmoi-daemon.service    # Systemd service file
│   └── chezmoi-daemon.timer      # Systemd timer file
├── docs/
│   └── README.md          # This file
├── install.sh             # Installation script
└── uninstall.sh           # Uninstallation script
```

## Installation

Run the installer from within the chezmoi-daemon directory:

```bash
cd ~/.local/share/chezmoi/chezmoi-daemon
chmod +x install.sh
./install.sh
```

The installer will:
1. Copy scripts to `~/scripts/`
2. Install systemd service files
3. Set up autostart entries for login triggers
4. Enable and start the systemd timer

## Usage

### Manual Trigger
```bash
~/scripts/chezmoi-trigger.sh
```

### Force Check (ignore previous ignore hash)
```bash
~/scripts/chezmoi-trigger.sh --force
```

### One-time Check
```bash
~/scripts/chezmoi-daemon.sh check
```

### Run in Daemon Mode
```bash
~/scripts/chezmoi-daemon.sh daemon
```

### Setup/Reinstall Triggers
```bash
~/scripts/chezmoi-daemon.sh setup
```

## Automatic Triggers

The daemon automatically checks for changes:
- **On login**: Via desktop autostart and Hyprland exec-once
- **Hourly**: Via systemd timer
- **Manual**: Via trigger script

## Configuration

The daemon uses these directories:
- **Cache**: `~/.cache/chezmoi-daemon/` - logs and ignore hash
- **Scripts**: `~/scripts/` - installed daemon and trigger scripts
- **Systemd**: `~/.config/systemd/user/` - service and timer files

## Logs

All daemon activity is logged to `~/.cache/chezmoi-daemon/daemon.log`.

View recent activity:
```bash
tail -f ~/.cache/chezmoi-daemon/daemon.log
```

## Uninstallation

Run the uninstaller:

```bash
cd ~/.local/share/chezmoi/chezmoi-daemon
chmod +x uninstall.sh
./uninstall.sh
```

The uninstaller will:
1. Stop and disable systemd services
2. Remove all installed files
3. Clean up autostart and Hyprland configurations
4. Optionally remove cache directory

## Development

The source files use chezmoi template syntax (`{{ .chezmoi.homeDir }}`, etc.) which is processed during installation to create the final scripts with proper paths.

To modify the daemon:
1. Edit files in `src/` directory
2. Run `./install.sh` to deploy changes
3. Test with `~/scripts/chezmoi-trigger.sh`

## Troubleshooting

### No notifications appearing
- Check if `notify-send` is installed: `which notify-send`
- Verify display environment: `echo $DISPLAY $WAYLAND_DISPLAY`
- Check daemon logs for errors

### Systemd timer not working
```bash
systemctl --user status chezmoi-daemon.timer
systemctl --user list-timers | grep chezmoi
```

### Manual debugging
```bash
# Check for changes manually
~/scripts/chezmoi-daemon.sh check

# Force a check
~/scripts/chezmoi-daemon.sh force

# View logs
tail -20 ~/.cache/chezmoi-daemon/daemon.log
```