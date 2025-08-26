# Idle Inhibitor System

A persistent idle inhibitor system for Hyprland with Waybar integration that maintains state across waybar reloads, starts disabled on login, and automatically disables when the screen is locked.

## Features

- **Persistent State**: Survives waybar reloads and configuration changes
- **Clean Startup**: Always starts with idle inhibitor OFF on login
- **Lock Detection**: Automatically disables when screen is manually locked
- **Visual Feedback**: Waybar module shows current state with icons
- **Toggle Control**: Click waybar module to enable/disable

## Architecture

```
idle-inhibitor/
├── executable_idle-inhibitor-daemon.sh  # Main daemon process
├── executable_waybar-module.sh         # Waybar display module
├── executable_toggle.sh                # State toggle script
├── modules/
│   └── base.sh                         # Shared functions
└── README.md                           # This file
```

## Installation

1. **Apply chezmoi configuration:**
   ```bash
   chezmoi apply
   ```

2. **Enable and start the systemd service:**
   ```bash
   systemctl --user enable --now idle-inhibitor-daemon.service
   ```

3. **Restart waybar to load the new configuration:**
   ```bash
   pkill waybar
   # Waybar should auto-restart via systemd
   ```

## How It Works

### State Management
- State stored in `/tmp/idle-inhibitor-state` (0=off, 1=on)
- `/tmp` location ensures state is cleared on reboot (OFF on login)
- Daemon monitors state file for changes

### Idle Inhibition
- Uses `systemd-inhibit --what=idle` for actual idle prevention
- PID stored in `/tmp/idle-inhibitor-systemd.pid` for process management
- Automatically restarts if systemd-inhibit process dies

### Lock Detection
- `lock_cmd` script creates signal file `/tmp/idle-inhibitor-lock-signal`
- Daemon monitors for signal file and disables inhibitor
- Integrates seamlessly with existing lock workflow

### Waybar Integration
- Custom module replaces built-in `idle_inhibitor`
- Returns JSON with icon, tooltip, and CSS class
- Refreshes via SIGRTMIN+9 signal when state changes

## Usage

### Manual Control
- **Toggle via Waybar**: Click the idle inhibitor icon
- **Command Line**: Run `~/.local/share/chezmoi/scripts/idle-inhibitor/toggle.sh`

### Automatic Behavior
- **On Login**: Idle inhibitor starts OFF
- **On Lock**: Idle inhibitor automatically turns OFF
- **On Waybar Reload**: State persists, no change

## Troubleshooting

### Check Service Status
```bash
systemctl --user status idle-inhibitor-daemon.service
```

### View Logs
```bash
journalctl --user -u idle-inhibitor-daemon.service -f
```

### Check Current State
```bash
cat /tmp/idle-inhibitor-state
```

### Verify systemd-inhibit
```bash
systemd-inhibit --list
```

## Configuration

The system is designed to work out-of-the-box without additional configuration. The daemon initializes with sensible defaults and integrates with existing Hyprland/waybar setup.

### Icons
- **Active** (󰅶): Eye open - idle inhibition active, screen stays awake
- **Inactive** (󰾪): Eye closed - normal idle behavior

### State File Locations
- `/tmp/idle-inhibitor-state`: Current inhibitor state (0/1)
- `/tmp/idle-inhibitor-systemd.pid`: systemd-inhibit process PID
- `/tmp/idle-inhibitor-lock-signal`: Lock event signal file