---
name: chezmoi
description: This skill should be used whenever the user mentions "chezmoi" in any way. Manages dotfiles with chezmoi including tracking config files, comparing dotfiles, checking status, working with chezmoi templates, and handling local file changes. CRITICAL SAFETY RULES ENFORCED.
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

## Handling Local Changes to Template Files

When a user reports that their local file has changes that differ from the chezmoi template:

### Critical Understanding
The user has ALREADY made changes to their local file and wants the template updated to MATCH those changes. Do NOT suggest applying the template to overwrite their local changes.

### Step-by-Step Process

1. **Identify the exact local changes:**
   ```bash
   chezmoi diff ~/.config/path/to/file
   ```
   This shows the difference between what chezmoi would generate vs what exists locally.

   **CRITICAL - Understanding the diff output:**
   - Lines starting with `-` show what the TEMPLATE would generate (template's current state)
   - Lines starting with `+` show what the LOCAL FILE contains (local file's current state)
   - These symbols indicate SOURCE, not chronology
   - To update template to match local: Replace template content that produces `-` lines with content that produces `+` lines

2. **Find the template source file:**
   ```bash
   chezmoi source-path ~/.config/path/to/file
   ```
   This returns the path to the `.tmpl` file (e.g., `~/.local/share/chezmoi/dot_config/path/to/file.tmpl`)

3. **Check modification timestamps to determine which is newer:**
   ```bash
   stat -c '%y %n' ~/.config/path/to/file && chezmoi source-path ~/.config/path/to/file | xargs stat -c '%y %n'
   ```
   This shows the modification times of both files. The newer file typically represents the user's intended state.
   - If local file is newer: User likely made intentional changes to be saved to the template
   - If template is newer: Template may have been updated from another machine or git pull
   - Present this information to help guide the decision

4. **Read both files to understand the exact difference:**
   - Read the template file directly to see its current content
   - Use `cat -A` or `od -c` to reveal hidden characters (trailing spaces, tabs, etc.)
   - Compare line-by-line, character-by-character if needed

5. **Confirm with user if needed:**
   - If timestamps are ambiguous or the change is significant, present the timestamp information and ask which direction to sync
   - Most commonly, the local file is newer and should be saved to the template

6. **Update the template to match the local file exactly:**
   - Edit the template file directly using the Edit tool
   - Pay attention to:
     - Commented vs uncommented lines
     - Trailing whitespace (spaces, tabs)
     - Line endings
     - Exact character positions

7. **Verify the fix:**
   ```bash
   chezmoi diff ~/.config/path/to/file
   ```
   This should show NO diff if the template was updated correctly.

### Common Pitfalls

- **Confusing diff symbols with chronology**: The `-` and `+` symbols show SOURCE (template vs local), NOT time (old vs new). Use timestamps to determine which change is newer.
- **Reading files instead of diff**: Always read BOTH the template file AND the local file directly to verify their actual content. Don't rely solely on diff interpretation.
- **Invisible whitespace**: Trailing spaces are significant. Use `cat -A` or `od -c` to see them.
- **Assuming templates need git commits**: Templates are read from the filesystem, not git HEAD. Changes take effect immediately without committing.
- **Swapping logic**: If local file has line A active and line B commented, the template must also have line A active and line B commented.

### Example Scenario

User says: "My local monitors.conf has changes"

**Correct approach:**
1. Run `chezmoi diff ~/.config/hypr/configs/monitors.conf`
2. Read the diff carefully - the `+` lines show what the local file contains
3. Find the template: `chezmoi source-path ~/.config/hypr/configs/monitors.conf`
4. Edit the template to match the local file (the `+` lines from the diff)
5. Verify with `chezmoi diff` - should show no differences

**Incorrect approach:**
- Suggesting `chezmoi apply` to overwrite local changes
- Misreading the diff and updating the template backwards
- Ignoring whitespace differences
- Claiming the template is correct when a diff still exists

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
