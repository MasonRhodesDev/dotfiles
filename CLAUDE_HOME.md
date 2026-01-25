# CLAUDE_HOME.md

Home directory specific instructions for Claude Code. This file is referenced by `~/.claude/CLAUDE.md` when working from `/home/mason`.

## Critical Workflow: Chezmoi-Managed Files

**BEFORE making ANY changes to files in this home directory (especially ~/.config, ~/.bashrc, etc.)**, you MUST check if they are managed by chezmoi.

### Always Check First:
```bash
chezmoi managed | grep -F "<relative-path-from-home>"
# or
chezmoi status <file-path>
```

### If File IS Managed by Chezmoi:
**DO NOT edit the live file directly**

Instead:
1. Navigate to the chezmoi source directory: `~/.local/share/chezmoi`
2. Find the source file:
   - `dot_config/hypr/hyprland.conf` → `~/.config/hypr/hyprland.conf`
   - `dot_bashrc` → `~/.bashrc`
   - `private_dot_ssh/config` → `~/.ssh/config`
3. Make changes in the source directory
4. Commit changes using `jj` (not git)
5. See `~/.local/share/chezmoi/CLAUDE.md` for detailed chezmoi commands

### If File is NOT Managed:
You can edit it directly in place.

## Chezmoi Dotfiles Repository

This home directory is managed by a chezmoi dotfiles repository for Fedora/Hyprland/Wayland system.

### Key Commands

- `chezmoi add <file>` - Track a LIVE file (copies ~/file → source directory)
- `chezmoi diff` - Compare source vs target (what would change)
- `chezmoi status` - Show tracked files with pending changes
- `chezmoi data` - Show template data values
- `chezmoi execute-template < file.tmpl` - Test template rendering

### Important Distinction

- **Live files** (`~/.config/foo`, `~/.bashrc`) - Use `chezmoi add` to track
- **Source repo files** (`~/.local/share/chezmoi/*`) - Commit with jj (not git)
- `chezmoi add` copies live → source; it cannot add files already in source

### Version Control

Use **jj** (Jujutsu) for all commits in this repo, not git directly.
- `jj status` - Check working copy state
- `jj log` - View history
- `jj bookmark set <name> -r <rev>` - Move bookmark to revision

#### Dual Trunk System

This repo uses two main bookmarks for syncing between machines:
- `work-pc` - Work machine (mason-work)
- `personal-pc` - Personal machine

**GitHub Rules (Base-Protection ruleset):** Applies to `*-pc` branches:
- No deletion
- No non-fast-forward (force) pushes

When merging:
1. Always create merge commits (don't rebase)
2. If origin diverges, merge origin into local before pushing: `jj new local-bookmark "bookmark@origin"`
3. After merge, both bookmarks should point to the same commit

#### Syncing Between Machines
```bash
# Fetch remote changes
jj git fetch

# Merge branches
jj new work-pc personal-pc -m "Merge personal-pc into work-pc"

# Resolve any conflicts, then update both bookmarks
jj bookmark set work-pc -r @
jj bookmark set personal-pc -r @

# Push both
jj git push --bookmark work-pc --bookmark personal-pc
```

### Architecture

- `dot_*` → `.*` files in home directory
- `private_*` → Files with restricted permissions
- `.tmpl` suffix → Go template files (processed before deploy)
- `run_*` → Scripts executed during apply
- `modify_*` → Scripts that modify existing files

### Directory Structure

- `software_installers/` - System setup scripts (`executable_0[3-4]_*.sh`)
- `scripts/` - Management utilities
- `scripts/hyprland-theme-toggle/` - Theme switching (`executable_theme-toggle-modular.sh [light|dark]`)
- `dot_config/` → `~/.config/`
- `lua/user/` - Neovim config (lazy.nvim)

### Template Variables

Access with `{{ .variable }}` syntax. Check available data with `chezmoi data`.
