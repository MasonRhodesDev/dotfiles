# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Software Installer Scripts

These scripts automate the installation and configuration of software for a Fedora-based Hyprland desktop environment.

## Execution Order

Scripts are numbered to run in dependency order:
1. `executable_00_utils.sh` - Basic utilities and foundations
2. `executable_01_terminal.sh` - Terminal emulators and shell tools  
3. `executable_02_node.sh` - Node.js and JavaScript tooling
4. `executable_03_hyprland.sh` - Hyprland compositor and Wayland tools
5. `executable_04_git_based.sh` - Git repository-based software
6. `executable_06_browser.sh` - Web browsers and related tools

## Key Commands

### Manual Execution
```bash
# Run all installers in order
for script in ./software_installers/executable_*.sh; do
    [ -x "$script" ] && "$script"
done

# Run specific installer
./software_installers/executable_03_hyprland.sh
```

### Dependencies
- Scripts assume Fedora with `dnf` package manager
- COPR repositories enabled for Hyprland ecosystem
- Git available for repository-based installations

## Script Architecture

### Safety Patterns
- `set -e` - Exit on any command failure
- `command -v <tool>` checks before installation
- Conditional installation prevents reinstalls

### Hyprland Script Highlights
- Enables required COPR repositories (solopasha/hyprland, heus-sueh/packages)
- Sets repository priorities for proper package resolution
- Installs complete Hyprland ecosystem (compositor, lock screen, picker, etc.)
- Enables systemd user services (waybar-reload.path)
- Installs and configures Go toolchain for hyprls language server

### Git-based Script Pattern
- Uses `run_if_exists()` helper for conditional execution
- Handles missing/non-executable scripts gracefully
- Runs git-based installers in dependency order (Astal libraries first)

## Development Guidelines

### Adding New Installers
1. Create numbered script following existing pattern
2. Include safety checks (`set -e`, existence checks)
3. Test installation on clean system
4. Update this documentation

### Platform Support
- Primary target: Fedora Linux
- Platform checks should use `command -v dnf` pattern
- Provide graceful fallbacks for unsupported platforms