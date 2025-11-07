---
name: plan
description: This skill should be used when the user requests help building a complex multi-phase project plan, resuming an existing plan from CURRENT_PLAN.md, or executing projects that require research, planning, building, validation, and cleanup phases. Use when users say "create a plan", "help me plan", show a CURRENT_PLAN.md file, or need structured project execution with memory optimization between phases.
---

# Plan

## Overview

Manage complex multi-phase projects with memory-optimized execution, persistent state tracking, and phase isolation. The skill orchestrates projects through research, planning, revision, building, validation, and cleanup phases while preventing context pollution between phases.

## When to Use This Skill

Trigger this skill when:
- User explicitly requests project planning: "create a plan", "help me plan this project"
- User shows a `CURRENT_PLAN.md` file with the META comment about resuming
- User describes a complex project requiring multiple phases
- User needs structured execution with clear checkpoints
- Project requires research before implementation
- Implementation would benefit from validation phase

**Do NOT use for:**
- Simple single-step tasks
- Tasks that can be completed immediately
- Quick bug fixes or minor changes

## Core Principles

### Memory Optimization
- **Phase Isolation**: Each phase operates with minimal context from previous phases
- **Summary-First**: Always load `phase_summary.md` before diving into detailed context
- **Knowledge Base**: Store cross-phase references in `.plans/knowledge-base/`
- **Explicit Outputs**: Each phase creates clear, minimal outputs for the next phase

### State Persistence
- **CURRENT_PLAN.md**: Central tracking file for plan progress and metadata
- **Resume-Friendly**: New Claude instances can pick up where previous ones left off
- **Git-Safe**: Automatically adds plan files to `.gitignore` in git repositories

## Workflow Decision Tree

```
User Request
    ↓
Does CURRENT_PLAN.md exist?
    ↓
    Yes → Resume Existing Plan (go to "Resuming a Plan")
    ↓
    No → Is this a complex multi-phase project?
        ↓
        Yes → Initialize New Plan (go to "Starting a New Plan")
        ↓
        No → This skill is not needed
```

## Starting a New Plan

### 1. Understand Project Goal

Ask clarifying questions if the goal is unclear:
- What is the project trying to achieve?
- Are there specific requirements or constraints?
- What does success look like?

### 2. Initialize Plan Structure

Use the orchestrator script to create the plan structure:

```bash
python3 /path/to/plan/scripts/orchestrator.py --dir . init "PROJECT_GOAL"
```

Replace `PROJECT_GOAL` with the actual project goal (in quotes).

**Optional**: Customize phases with `--phases`:
```bash
python3 /path/to/plan/scripts/orchestrator.py --dir . init "PROJECT_GOAL" --phases research planning building validation
```

This creates:
- `CURRENT_PLAN.md` - Central tracking file
- `.plans/` - Phase directories
- `.plans/knowledge-base/` - Cross-phase references
- Updates `.gitignore` if in git repo

### 3. Create Phase Templates

For each phase, create a plan template:

```bash
python3 /path/to/plan/scripts/phase_templates.py <phase_name> .plans/<phase_name>/plan.md
```

Available phases: `research`, `planning`, `revision`, `building`, `validation`, `cleanup`

### 4. Begin First Phase

Start with the first phase (typically `research`):

1. Read the phase plan: `.plans/research/plan.md`
2. Execute phase according to template
3. Create required outputs:
   - Phase-specific outputs (e.g., `research_findings.md`)
   - `phase_summary.md` - Concise summary (<500 words)
4. Update plan status:
   ```bash
   python3 /path/to/plan/scripts/orchestrator.py --dir . update research completed --outputs "research_findings.md" "phase_summary.md"
   ```

### 5. Continue Through Phases

For each subsequent phase:

1. **Load Only Summary Context**:
   - Read previous phase's `phase_summary.md`
   - Do NOT load full previous phase context
   - Load knowledge base files on-demand only

2. **Execute Phase**:
   - Follow phase plan template
   - Create phase-specific outputs
   - Always create `phase_summary.md`

3. **Update Progress**:
   ```bash
   python3 /path/to/plan/scripts/orchestrator.py --dir . update <phase> completed --outputs "<output1>" "<output2>"
   ```

4. **Move to Next Phase**:
   - Repeat until all phases complete

## Resuming a Plan

When a `CURRENT_PLAN.md` file exists with the META comment, resume the plan:

### 1. Check Current Status

```bash
python3 /path/to/plan/scripts/orchestrator.py --dir . status
```

This shows:
- Current phase
- Completed phases
- Project goal

### 2. Load Current Phase Context

**IMPORTANT**: Load ONLY the current phase context:

1. Read `CURRENT_PLAN.md` to understand overall goal
2. Read `.plans/<current_phase>/plan.md` for phase instructions
3. Read previous phase's `phase_summary.md` (not full context)
4. Read knowledge base files on-demand only

**DO NOT**:
- Load full context from previous phases
- Read all phase directories
- Load outputs from non-adjacent phases

### 3. Continue Execution

Pick up where the previous instance left off:
- If phase is in progress, continue from where it stopped
- Follow phase plan and create required outputs
- Update CURRENT_PLAN.md when phase completes

## Phase Workflows

Detailed workflows for each phase are in `references/phase_workflows.md`. Key points:

### Research Phase
- **Purpose**: Gather information to understand problem space
- **Outputs**: `research_findings.md`, knowledge base files, `phase_summary.md`
- **Memory**: High budget for exploration

### Planning Phase
- **Purpose**: Design solution based on research
- **Inputs**: Research `phase_summary.md` only
- **Outputs**: `plan.md`, `architecture.md`, `phase_summary.md`
- **Memory**: Medium budget, focused on design

### Revision Phase
- **Purpose**: Review and refine the plan
- **Inputs**: Planning outputs
- **Outputs**: `review_notes.md`, `revised_plan.md` (if needed), `phase_summary.md`
- **Memory**: Medium budget for review

### Building Phase
- **Purpose**: Implement the solution
- **Inputs**: Plan and revision summary
- **Outputs**: Implementation artifacts, `implementation_log.md`, `phase_summary.md`
- **Memory**: Low for plan context, high for implementation

### Validation Phase
- **Purpose**: Verify implementation
- **Inputs**: Building summary
- **Outputs**: `validation_results.md`, `issues.md`, `phase_summary.md`
- **Memory**: Low budget, focused validation

### Cleanup Phase
- **Purpose**: Finalize and optionally remove plan files
- **Inputs**: All phase summaries
- **Outputs**: `final_summary.md`
- **Memory**: Minimal, summaries only

## Memory Management Patterns

### Pattern 1: Summary Cascade
Each phase loads only the previous phase's summary:
```
Research → phase_summary.md → Planning → phase_summary.md → Revision
```

### Pattern 2: Knowledge Base
Store cross-phase references centrally:
```
Research creates: .plans/knowledge-base/api_schema.md
Building loads: api_schema.md when implementing API
```

### Pattern 3: Progressive Disclosure
Load context in layers:
1. First: Load `phase_summary.md`
2. If needed: Load specific sections from detailed files
3. If needed: Load knowledge base references
4. Never: Load full previous phase context

## Iteration Strategy

If a phase reveals issues requiring iteration:

1. Document reason in `phase_summary.md`
2. Update `CURRENT_PLAN.md` with iteration note
3. Return to appropriate phase
4. Create `iteration_01_plan.md` for the iteration
5. Resume forward progress

**Limit**: Max 2-3 iterations per phase to avoid infinite loops

## Cleanup

After plan completion, optionally clean up plan files:

```bash
python3 /path/to/plan/scripts/orchestrator.py --dir . cleanup
```

This removes:
- `CURRENT_PLAN.md`
- `.plans/` directory

**Confirm with user before cleanup** - they may want to keep plan files for reference.

## Best Practices

### DO:
- Create concise `phase_summary.md` files (<500 words)
- Store cross-phase references in `knowledge-base/`
- Load only summaries unless details are needed
- Update `CURRENT_PLAN.md` after each phase
- Use structured outputs (markdown, JSON)
- Ask clarifying questions before starting

### DON'T:
- Load full previous phase context by default
- Copy content between phases
- Skip `phase_summary.md` creation
- Forget to update `CURRENT_PLAN.md`
- Mix phase concerns
- Use for simple single-step tasks

## Resources

### scripts/orchestrator.py
Python script for managing plan lifecycle:
- `init` - Initialize new plan
- `status` - Show current status
- `update` - Update phase status
- `cleanup` - Remove plan files

### scripts/phase_templates.py
Generate phase plan templates for each phase type with structured objectives, inputs, outputs, and process steps.

### references/phase_workflows.md
Comprehensive documentation of each phase workflow, including:
- Detailed process for each phase
- Memory management strategies
- Input/output specifications
- Iteration patterns
- Best practices

Load this file when more detailed guidance is needed for a specific phase.

## Example Usage

### Starting a New Plan

```
User: "I need to build a REST API for user authentication. Can you help me plan this?"

Claude:
1. This is a complex project - I'll use the plan skill
2. Initialize plan with goal: "Build REST API for user authentication"
3. Start research phase:
   - Explore existing auth patterns in codebase
   - Document findings in knowledge base
   - Create research summary
4. Move to planning phase:
   - Load research summary
   - Design API architecture
   - Create implementation plan
5. Continue through remaining phases...
```

### Resuming a Plan

```
User: "Here's the CURRENT_PLAN.md from our API project"

Claude:
1. Notice META comment about resuming with plan skill
2. Check status: Currently in "building" phase
3. Load building/plan.md and planning/phase_summary.md
4. Continue implementation from where it left off
5. Update CURRENT_PLAN.md when building completes
6. Move to validation phase
```

## Troubleshooting

### "Phase is taking too long"
- Break phase into smaller sub-tasks
- Consider if phase scope is too large
- May need iteration back to planning

### "Too much context loading"
- Verify loading only `phase_summary.md` from previous phases
- Check knowledge base files are concise (<2000 words)
- Ensure not loading full previous phase context

### "Lost track of progress"
- Always check `CURRENT_PLAN.md` status
- Run orchestrator status command
- Review phase summaries to catch up

### "Need to change plan mid-execution"
- Document reason in current `phase_summary.md`
- Return to planning or revision phase
- Create iteration plan
- Resume from updated plan
