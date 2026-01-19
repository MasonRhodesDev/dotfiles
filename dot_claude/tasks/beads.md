# Beads (bd) - Task Tracking

## Overview

Use `bd` (beads) for structured task tracking in projects. Git-backed dependency-aware task graphs replace unorganized markdown plans. Tasks stored in `.beads/` directory as JSONL files.

## Essential Commands

- `bd init` - Initialize in a repository (or `--stealth` for local-only)
- `bd create` - Create new task/issue
- `bd list` - List tasks
- `bd show <id>` - Show task details
- `bd dep` - Manage task dependencies
- `bd ready` - Show tasks ready to work on (no blockers)
- `bd close <id>` - Close completed task
- `bd graph` - Display dependency graph
- `bd status` - Show database overview

## When to Use

- Prefer beads over ad-hoc TODO lists for complex, multi-step projects
- Use for projects with task dependencies
- Use when tasks need to be tracked across sessions
- Use for multi-agent or long-running projects

## Modes

- **Standard mode**: Tasks committed to git (recommended for multi-machine sync)
- **Stealth mode**: Tasks stay local, not committed to repo (`bd init --stealth`)
