# Chezmoi Dotfiles Repository

Dotfiles repository for Fedora/Hyprland/Wayland system. Uses Go templates (.tmpl) with automated installers and theme management.

## Key Commands

- `chezmoi add <file>` - Track a LIVE file (copies ~/file → source directory)
- `chezmoi diff` - Compare source vs target (what would change)
- `chezmoi status` - Show tracked files with pending changes
- `chezmoi data` - Show template data values
- `chezmoi execute-template < file.tmpl` - Test template rendering

## Important Distinction

- **Live files** (`~/.config/foo`, `~/.bashrc`) - Use `chezmoi add` to track
- **Source repo files** (`~/.local/share/chezmoi/*`) - Auto-committed by chezmoi (`autoCommit=true`, `autoPush=true`)
- `chezmoi add` copies live → source; it cannot add files already in source

## Version Control

Single branch `main`. Chezmoi auto-commits and auto-pushes via git (`autoCommit=true`, `autoPush=true`).

## Architecture

- `dot_*` → `.*` files in home directory
- `private_*` → Files with restricted permissions
- `.tmpl` suffix → Go template files (processed before deploy)
- `run_*` → Scripts executed during apply
- `modify_*` → Scripts that modify existing files

## Directory Structure

- `software_installers/` - System setup scripts (`executable_0[3-4]_*.sh`)
- `scripts/` - Management utilities
- `scripts/hyprland-theme-toggle/` - Theme switching (`executable_theme-toggle-modular.sh [light|dark]`)
- `dot_config/` → `~/.config/`
- `lua/user/` - Neovim config (lazy.nvim)

## Template Variables

Access with `{{ .variable }}` syntax. Check available data with `chezmoi data`.
