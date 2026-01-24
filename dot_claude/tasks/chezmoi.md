# Chezmoi Operations

## Safety Rules

- `chezmoi apply` is safe - it will show conflicts and prompt for resolution
- NEVER use `--force` flags (e.g., `chezmoi apply --force`) - this bypasses safety checks and overwrites files
- Use `chezmoi diff` to preview changes (compares rendered templates with target files)
- Use `chezmoi apply --dry-run` to see what would be applied without actually applying
- Use `chezmoi add` to save local changes TO tracking
- See `~/.local/share/chezmoi/CLAUDE.md` for repo-specific commands and structure
- Primary branch: `personal-pc`

## Key Commands

- `chezmoi add <file>` - Track a LIVE file (copies ~/file → source directory)
- `chezmoi diff` - Compare source vs target (what would change)
- `chezmoi status` - Show tracked files with pending changes
- `chezmoi data` - Show template data values
- `chezmoi execute-template < file.tmpl` - Test template rendering

## Important Distinction

- **Live files** (`~/.config/foo`, `~/.bashrc`) - Use `chezmoi add` to track
- **Source repo files** (`~/.local/share/chezmoi/*`) - Commit with jj (not git)
- `chezmoi add` copies live → source; it cannot add files already in source
