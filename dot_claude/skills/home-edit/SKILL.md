---
name: home-edit
description: Use this skill when editing files in the home directory (~/) or .config directory. Syncs chezmoi repository (work-pc/personal-pc), checks management status, and routes edits to the correct location. ALWAYS sync and check chezmoi before editing.
hooks:
  PreToolUse:
    - matcher: "Bash|Read|Edit|Write"
      hooks:
        - type: command
          command: "chezmoi managed"
          once: true
  Stop:
    - type: command
      command: "chezmoi verify"
---

# Home Directory File Editing

## When to Use
Use this skill automatically when the user requests to edit files in:
- `~/` (home directory root)
- `~/.config/` (configuration directory)
- `~/.bashrc`, `~/.zshrc`, or other common dotfiles
- ANY file that might be managed by chezmoi

## CRITICAL: Always Sync and Check Chezmoi First

**BEFORE making ANY edits**, you MUST:

1. **Sync the repository** (Step 0 below) - fetch and merge remote changes
2. **Check if the file is managed** by running:
```bash
chezmoi managed
```

Store this output and check if the target file appears in the list.

## Workflow

### Step 0: Sync Repository (ALWAYS DO FIRST)

Before making ANY changes, sync the chezmoi repository:

```bash
# Get hostname to determine branch
hostname

# Navigate to chezmoi repo
cd ~/.local/share/chezmoi

# Fetch remote changes
jj git fetch

# Check current bookmark
jj log -r @ --no-graph
```

**Determine the correct branch based on hostname:**
- `mason-work` → use `work-pc` bookmark
- `mason-desktop` or other → use `personal-pc` bookmark

**Check if you need to sync:**
```bash
# Check if local bookmark is behind origin
jj log -r "bookmark_name@origin"
```

**If origin has changes, merge them:**
```bash
# Merge origin into local bookmark
jj new bookmark_name "bookmark_name@origin" -m "Merge remote changes from bookmark_name"

# Update bookmark to point to the merge
jj bookmark set bookmark_name -r @
```

**Important:** Always complete this sync step BEFORE checking chezmoi managed status or making edits. This ensures you're working with the latest configuration.

### Step 1: Check Management Status
```bash
# Get all managed files
chezmoi managed

# Or check specific file
chezmoi managed | grep -F "path/to/file"
```

### Step 2: Route to Correct Location

#### If File IS Managed by Chezmoi:
1. **DO NOT** edit the live file directly
2. Find the source file:
   ```bash
   chezmoi source-path ~/path/to/file
   ```
3. Read BOTH files to understand the current state:
   - Read the source file (may be a `.tmpl` with conditionals)
   - Read the target file (the live file)
4. Edit the source file, **preserving all template logic**:
   - Keep all `{{ if }}...{{ end }}` conditionals
   - Keep all `{{ .variable }}` template variables
   - Merge the desired changes INTO the template structure
5. Changes take effect immediately (chezmoi reads from filesystem)
6. Commit changes using `jj` (not git):
   ```bash
   cd ~/.local/share/chezmoi
   jj status
   jj commit -m "Update configuration"
   ```

#### If File is NOT Managed:
1. Edit the file directly in place
2. Consider if it SHOULD be tracked by chezmoi
3. If yes, suggest: `chezmoi add ~/path/to/file`

### Step 3: Verify Changes
```bash
# For managed files, verify no diff remains
chezmoi diff ~/path/to/file

# Should show no output if source is correctly updated
```

## File Path Mapping

Chezmoi uses special naming conventions in the source directory:

| Live File | Source File |
|-----------|-------------|
| `~/.config/foo/bar.conf` | `~/.local/share/chezmoi/dot_config/foo/bar.conf` |
| `~/.bashrc` | `~/.local/share/chezmoi/dot_bashrc` |
| `~/.ssh/config` | `~/.local/share/chezmoi/private_dot_ssh/config` |
| `~/.config/hypr/hyprland.conf.tmpl` | `~/.local/share/chezmoi/dot_config/hypr/hyprland.conf.tmpl` |

Patterns:
- `dot_*` → `.*` (hidden files)
- `private_*` → restricted permissions
- `.tmpl` → Go template files (PRESERVE template logic!)

## Template Files (.tmpl)

For files ending in `.tmpl`:
1. **ALWAYS read the template first** to see existing structure
2. **PRESERVE** all template conditionals (`{{ if }}...{{ end }}`)
3. **PRESERVE** all template variables (`{{ .chezmoi.hostname }}`)
4. **MERGE** changes into the template structure, don't replace it
5. Test rendering: `chezmoi execute-template < source-file.tmpl`

### Example: Merging Changes into a Template

If the source is:
```
{{ if eq .chezmoi.hostname "mason-desktop" }}
monitor=DP-1,2560x1440@144,0x0,1
{{ else }}
monitor=eDP-1,1920x1080@60,0x0,1
{{ end }}
```

And you need to change the desktop resolution to 3840x2160, merge into the template:
```
{{ if eq .chezmoi.hostname "mason-desktop" }}
monitor=DP-1,3840x2160@144,0x0,1
{{ else }}
monitor=eDP-1,1920x1080@60,0x0,1
{{ end }}
```

**Don't** remove the conditionals and just set one value!

## Version Control

The chezmoi repository uses **jj** (Jujutsu), not git:
```bash
cd ~/.local/share/chezmoi
jj status              # Check working copy state
jj commit -m "msg"     # Commit changes
jj log                 # View history
```

See `~/CLAUDE_HOME.md` for dual-trunk workflow details.

## Safety Rules

⚠️ **NEVER:**
- Edit live files when they're managed by chezmoi
- Use `chezmoi apply` (overwrites local changes)
- Use `--force` flags
- Skip the `chezmoi managed` check
- Remove template conditionals or variables
- Copy/replace template content without reading it first

✅ **ALWAYS:**
- Sync repository first (Step 0): fetch and merge remote changes
- Determine correct bookmark (work-pc vs personal-pc) based on hostname
- Check `chezmoi managed` first
- Read BOTH source and target files
- Preserve template logic when editing `.tmpl` files
- Merge changes INTO templates, don't replace them
- Edit source files for managed files
- Commit changes with `jj`
- Verify with `chezmoi diff`

## Quick Reference

```bash
# STEP 0: Always sync first
hostname  # Determine work-pc or personal-pc
cd ~/.local/share/chezmoi
jj git fetch
jj log -r @ --no-graph  # Check current position
# If origin has changes: jj new bookmark_name "bookmark_name@origin" -m "Merge remote"
# Then: jj bookmark set bookmark_name -r @

# Check if file is managed
chezmoi managed | grep -F "path/to/file"

# Find source path
chezmoi source-path ~/path/to/file

# Read both files
cat ~/path/to/file
cat $(chezmoi source-path ~/path/to/file)

# Edit source (if managed)
cd ~/.local/share/chezmoi
# Read dot_config/path/to/file first to see template logic
# Edit dot_config/path/to/file, merging changes

# Verify
chezmoi diff ~/path/to/file

# Commit
jj commit -m "Update file"
```

## Common Files That ARE Managed

Most files in these locations are typically managed by chezmoi:
- `~/.config/hypr/` - Hyprland configuration
- `~/.config/waybar/` - Waybar configuration
- `~/.config/fish/` - Fish shell configuration
- `~/.config/nvim/` - Neovim configuration
- `~/.bashrc`, `~/.zshrc` - Shell configs

Always verify with `chezmoi managed` to be certain.

## Error Recovery

If you accidentally edited a managed file directly:
1. Check the diff: `chezmoi diff ~/path/to/file`
2. Read the source: `cat $(chezmoi source-path ~/path/to/file)`
3. Note your changes from the live file
4. Edit the source file, **merging** your changes into any template structure
5. Verify: `chezmoi diff` shows no difference

## Integration with CLAUDE_HOME.md

This skill enforces the workflow documented in `~/CLAUDE_HOME.md`. See that file for:
- Complete chezmoi command reference
- Dual-trunk workflow details
- Architecture and directory structure
- Template variable usage
