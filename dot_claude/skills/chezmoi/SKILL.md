---
name: chezmoi
description: Manage dotfiles with chezmoi. Use when user needs to track config files, compare dotfiles, check status, or work with chezmoi templates. CRITICAL SAFETY RULES ENFORCED.
---

# Chezmoi Dotfiles Management

## When to Use
Use this skill when the user needs to:
- Track configuration file changes with chezmoi
- Compare local files with chezmoi-managed versions
- Check chezmoi status or differences
- Work with chezmoi templates (.tmpl files)
- Update dotfiles repository

## CRITICAL SAFETY RULES

⚠️ **NEVER use these dangerous commands:**
- `chezmoi apply` - Overwrites local changes with stored config (destructive!)
- `chezmoi apply --force` - Bypasses safety checks
- Any command with `--force` flag

✅ **Safe workflow:**
- `chezmoi add <file>` - Add local changes TO chezmoi tracking
- `chezmoi diff` - Compare tracked config with local files
- `chezmoi status` - Show files needing updates

## Common Commands

### Track Local Changes
```bash
chezmoi add ~/.config/hypr/hyprland.conf
```
This saves the current local file to chezmoi's source directory.

### Check What Changed
```bash
chezmoi diff
```
Shows differences between chezmoi's tracked version and local files.

### Check Status
```bash
chezmoi status
```
Lists files that differ between chezmoi source and local system.

### Test Template Rendering
```bash
chezmoi execute-template < ~/.local/share/chezmoi/dot_config/example.conf.tmpl
```
Previews how a template will render without applying it.

### Source Directory Location
Chezmoi source files are stored in `~/.local/share/chezmoi/`
- `dot_*` files become `.*` in home directory
- `.tmpl` files are processed as Go templates

## Workflow Pattern

1. **User edits local config file** (e.g., `~/.bashrc`)
2. **Add changes to chezmoi:** `chezmoi add ~/.bashrc`
3. **Verify with diff:** `chezmoi diff` (optional)
4. **Commit changes:** Standard git operations in `~/.local/share/chezmoi/`

## Template Variables

Access chezmoi data in templates:
```
{{ .chezmoi.hostname }}
{{ .chezmoi.os }}
{{ .chezmoi.username }}
```

## Error Handling

If chezmoi commands fail:
- Check if file is tracked: `chezmoi managed | grep filename`
- Verify source directory: `ls ~/.local/share/chezmoi/`
- Check for template errors: `chezmoi execute-template` on specific file

## When NOT to Use Chezmoi

Do not use chezmoi commands for:
- Files not in the dotfiles repository
- Temporary files or caches
- Files with secrets (use chezmoi's encrypted files feature instead)
