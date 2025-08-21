# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Hyprland Theme Toggle System

A modular theme management system that generates Material You colors from wallpapers and applies consistent theming across all desktop applications.

## Key Commands

### Theme Switching
```bash
# Toggle between light/dark mode
./executable_theme-toggle-modular.sh

# Set specific theme mode
./executable_theme-toggle-modular.sh dark
./executable_theme-toggle-modular.sh light
```

### Theme State
- State stored in `~/.cache/theme_state`
- Wallpaper path: `~/Pictures/forrest.png`

## Architecture Overview

### Core Components
- `executable_theme-toggle-modular.sh` - Main orchestrator script
- `modules/base.sh` - Shared utility functions  
- `modules/*.sh` - Application-specific theme modules

### Theme Generation Pipeline
1. **Read current state** from `~/.cache/theme_state`
2. **Generate colors** using `matugen` from wallpaper
3. **Apply themes** by running all module scripts in parallel
4. **Update state file** with new theme mode

### Matugen Integration
```bash
matugen image "$WALLPAPER_PATH" --mode "$MATUGEN_MODE" --type scheme-expressive
```
- Generates Material You color schemes
- Creates color templates for various applications
- Supports both light and dark modes

## Module System

### Module Structure
Each module in `modules/` handles theming for specific applications:
- `gtk.sh` - GTK applications and themes
- `hyprpanel.sh` - Hyprland panel theming  
- `qt.sh` - Qt application theming
- `wezterm.sh` - WezTerm terminal theming
- `wofi.sh` - Wofi launcher theming
- `vscode.sh` - VS Code theme switching
- `tmux.sh` - Tmux status bar theming

### Module Execution
- All modules run **in parallel** for performance
- Background execution with PID tracking
- Error handling per module (failures don't stop others)

### Base Functions (`modules/base.sh`)
```bash
get_theme_state()     # Read current theme from state file
run_module()          # Execute module with error handling  
wait_for_modules()    # Wait for all background processes
```

## Development Guidelines

### Adding New Application Support
1. Create new module file: `modules/app-name.sh`
2. Implement theme switching logic using matugen colors
3. Test both light and dark modes
4. Module should handle missing applications gracefully

### Module Requirements
- Must check if application is installed before theming
- Should use matugen-generated color files from `~/.config/matugen/`
- Include error handling for file operations
- Exit with appropriate status codes

### Color Template Integration
- Templates located in `~/.config/matugen/templates/`
- Generated config files placed in appropriate app directories
- Modules apply generated configs and trigger app refreshes