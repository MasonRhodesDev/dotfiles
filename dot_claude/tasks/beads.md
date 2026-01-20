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

**MANDATORY for projects with `.beads/` directory** - If beads is initialized, always use it.

Use beads when:
- ✅ Complex, multi-step projects (prefer over ad-hoc TODO lists)
- ✅ Tasks have dependencies (A must complete before B)
- ✅ Work spans multiple sessions (track progress over time)
- ✅ Multi-agent or long-running projects
- ✅ Planning phase complete (convert plan into trackable tasks)

**Integration with Planning:**
After completing EnterPlanMode:
1. Create beads tasks from plan: `bd create "Task description"`
2. Set dependencies: `bd dep add <parent-id> <child-id>`
3. Track work: `bd ready` to find next available task
4. Update status: `bd update <id> --status in_progress`
5. Close completed: `bd close <id>`

## Modes

- **Standard mode**: Tasks committed to git (recommended for multi-machine sync)
- **Stealth mode**: Tasks stay local, not committed to repo (`bd init --stealth`)
