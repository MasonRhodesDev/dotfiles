# CLAUDE.md

Global guidance for Claude Code when working in this user's repositories.

# Repository Context

**Chezmoi dotfiles repository** for Fedora/Hyprland/Wayland. Uses templates (.tmpl) with automated installers and theme management.

## Key Commands

- `chezmoi add <file>` - Track changes (NEVER use `chezmoi apply`)
- `chezmoi diff/status` - Compare/check tracked files
- `./software_installers/executable_0[3-4]_*.sh` - Install system components
- `./scripts/hyprland-theme-toggle/executable_theme-toggle-modular.sh [light|dark]` - Switch theme

## Architecture

- `dot_*` → `.*` files in home directory
- `.tmpl` files are Go templates
- `software_installers/` - System setup scripts
- `scripts/` - Management utilities
- `lua/user/` - Neovim config (lazy.nvim)

# Development Guidelines

## Core Principles
- Only implement what's explicitly requested (no feature creep)
- Keep solutions simple (KISS principle)
- Reference ~/CLAUDE_HOME.md when working from /home/mason
- No self-attribution in commits/comments/code
- Follow existing patterns and conventions
- Never expose secrets or sensitive data
- Comments only when requested

## Task Management
- **CRITICAL: Delegate to subagents by default** - Only handle trivial single-step operations directly
- **CRITICAL: Use plan skill for non-trivial work** - Mandatory for multi-phase tasks
- **Subagent types**:
  - general-purpose: Multi-step tasks, complex research, uncertain searches
  - Explore: Codebase exploration, architecture questions, pattern searches
  - Plan: Structured planning before implementation
  - Launch in parallel when tasks are independent
- Use TodoWrite for multi-step tasks (one in_progress at a time, complete immediately)

## File Operations
- Edit over create (prefer modifying existing files)
- No proactive documentation (no README.md unless requested)
- **CRITICAL: Planning files go in .plans/** - All planning/tracking markdown files
- Use absolute paths
- Read before write

## Code Changes
- Delegate complex implementations to general-purpose agent (multi-file, new features, refactors)
- Use ts-refactor skill for large JS/TS refactorings (AST-based symbol renames, import updates)
- Verify dependencies before assuming availability
- Match existing imports and patterns
- Assume dev tools already running
- Validate only after completing entire task (scope to changed files unless requested)

## Git Operations
- Only commit when explicitly requested
- Descriptive messages (focus on "why" not "what")
- Use git status/diff to stage all changes
- Retry commits once if pre-commit hooks make changes

## Chezmoi Operations
- **NEVER use `chezmoi apply`** (overwrites local changes)
- **NEVER use `--force` flags** (bypasses safety)
- Use `chezmoi add` to save local changes TO tracking

## Search and Analysis
- **CRITICAL: Delegate codebase exploration to Explore agent** - Use for structure questions, patterns, context gathering
- Examples requiring Explore: "Where are errors handled?", "How does auth work?", "What's the structure?", "Find all API endpoints"
- Use Grep/Glob directly ONLY for needle queries (specific known symbols, file names, single patterns)
- Batch independent operations in parallel

## Communication
- Keep responses under 4 lines unless detail requested
- No unnecessary explanations or summaries
- Direct answers (no preamble/postamble)
- No emojis unless requested