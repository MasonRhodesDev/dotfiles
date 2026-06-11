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

- `software_installers/packages.toml` - Declarative package registry (repo-only, see docs/SOFTWARE-INSTALLERS.md)
- `scripts/` - Management utilities (deployed to `~/scripts/`)
- `dot_config/` → `~/.config/`
- Theme switching: `lmtt switch light|dark|toggle` (external tool, see docs/THEME-SYSTEM.md)

## Template Variables

Access with `{{ .variable }}` syntax. Check available data with `chezmoi data`.

## greetd Config (external)

greetd config has been extracted to its own repo: https://github.com/MasonRhodesDev/greetd-config

- Location: `/opt/greetd-config` (owned `root:opt`)
- Install: `sudo /opt/greetd-config/install.sh`
- Update: `sudo /opt/greetd-config/install.sh --update`
- Static files are symlinked into `/etc/greetd/` — edits in the repo take effect immediately
