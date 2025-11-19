# git-generate-commit

Simple commit message generator that analyzes your staged changes and creates a conventional commit message under 108 characters.

## Usage

```bash
# Stage your changes
git add <files>

# Generate commit message
git-generate-commit
```

The tool will output a suggested commit in the format:
```
type(scope): description
```

## Format

- **type**: Automatically determined from changes (feat, fix, docs, test, chore, refactor)
- **scope**: Optional, derived from directory or filename
- **description**: Brief summary of changes
- **limit**: Maximum 108 characters total

## Examples

```bash
# Single file change
$ git add src/api/users.ts
$ git-generate-commit
📝 Generated commit message:
  feat(users): add user API

# Multiple files
$ git add tests/*.test.ts
$ git-generate-commit
📝 Generated commit message:
  test: update tests

# Documentation
$ git add README.md docs/api.md
$ git-generate-commit
📝 Generated commit message:
  docs: update documentation
```

## How It Works

1. Reads `git diff --staged`
2. Analyzes file paths and diff content
3. Determines appropriate type:
   - `docs`: README/markdown files
   - `test`: Test files
   - `fix`: Contains fix/bug/issue keywords
   - `feat`: New additions or significant changes
   - `chore`: Config/package files
   - `refactor`: Code reorganization
4. Extracts scope from directory/filename
5. Generates concise description
6. Ensures <108 character limit

## Installation

Managed via chezmoi dotfiles:
```bash
# Already installed at ~/.local/bin/git-generate-commit
# Ensure ~/.local/bin is in your PATH
```

## Customization

Edit the script at:
```
~/.local/share/chezmoi/dot_local/bin/executable_git-generate-commit
```

Then apply:
```bash
chezmoi apply ~/.local/bin/git-generate-commit
```
