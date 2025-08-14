# Development Guidelines

## Core Principles
- **Scope discipline**: Only implement what's explicitly requested. No feature creep.
- **KISS principle**: Keep solutions simple and direct. Avoid over-engineering.
- **Environment awareness**: When working from /home/mason directory, also reference ~/CLAUDE_HOME.md for system-specific context.

## Code Standards
- **No self-attribution**: Never add Claude attribution to commits, comments, or code
- **Follow existing patterns**: Match the codebase's style, libraries, and conventions
- **Security first**: Never expose secrets, keys, or sensitive data
- **Comments only when requested**: Don't add explanatory comments unless explicitly asked

## Task Management
- **Use TodoWrite extensively**: Plan and track all multi-step tasks
- **One task at a time**: Mark only one todo as "in_progress" 
- **Complete immediately**: Mark todos as completed right after finishing them
- **Be specific**: Break large tasks into actionable steps

## File Operations
- **Edit over create**: Always prefer modifying existing files to creating new ones
- **No proactive documentation**: Never create README.md or documentation files unless explicitly requested
- **Absolute paths**: Use absolute paths for all file operations
- **Read before write**: Always read existing files before modifying them

## Code Changes
- **Verify dependencies**: Check project dependencies before assuming libraries are available
- **Match existing imports**: Use the same libraries and patterns as surrounding code
- **Assume dev tools running**: Development servers and build loops are already running
- **Final validation only**: Run lint/typecheck/test commands only after completing entire task
- **Scope validation**: Limit validation to only files that changed unless broader scope requested

## Git Operations  
- **No auto-commits**: Only commit when explicitly requested by the user
- **Descriptive messages**: Focus on "why" rather than "what" in commit messages
- **Include all changes**: Use git status/diff to ensure all relevant changes are staged
- **Handle pre-commit hooks**: Retry commits once if hooks make changes

## Chezmoi Operations
- **NEVER use `chezmoi apply`**: This overwrites local changes with stored config
- **NEVER use `--force` flags**: This bypasses safety checks
- **Use `chezmoi add` to save changes**: Add local changes TO chezmoi tracking

## Search and Analysis
- **Use Task tool for complex searches**: Delegate multi-round searches to specialized agents
- **Batch tool calls**: Run independent operations in parallel when possible
- **Search thoroughly**: Use Grep, Glob, and Read tools extensively to understand codebases

## Communication
- **Be concise**: Keep responses under 4 lines unless detail is requested
- **No unnecessary explanation**: Don't summarize actions unless asked
- **Direct answers**: Answer questions without preamble or postamble
- **No emojis**: Unless explicitly requested by the user

- The first thing that happens in a new session should be checking the current working path and seeing if there are any rules special rules associtated