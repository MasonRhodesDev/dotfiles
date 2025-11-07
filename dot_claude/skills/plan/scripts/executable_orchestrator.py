#!/usr/bin/env python3
"""
Plan Orchestrator - Manages multi-phase project execution with memory optimization.

This script provides utilities for:
- Creating and initializing plan structures
- Tracking phase progress in CURRENT_PLAN.md
- Managing phase transitions with memory isolation
- Resuming interrupted plans
"""

import json
import os
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional


class PlanOrchestrator:
    """Manages plan lifecycle and phase transitions."""

    PHASES = [
        "research",
        "planning",
        "revision",
        "building",
        "validation",
        "cleanup"
    ]

    def __init__(self, working_dir: str = "."):
        self.working_dir = Path(working_dir).resolve()
        self.plan_file = self.working_dir / "CURRENT_PLAN.md"
        self.plans_dir = self.working_dir / ".plans"
        self.knowledge_base_dir = self.plans_dir / "knowledge-base"

    def initialize_plan(self, goal: str, phases: Optional[List[str]] = None) -> None:
        """Initialize a new plan structure."""
        # Create directories
        self.plans_dir.mkdir(exist_ok=True)
        self.knowledge_base_dir.mkdir(exist_ok=True)

        # Create phase directories
        for phase in phases or self.PHASES:
            (self.plans_dir / phase).mkdir(exist_ok=True)

        # Initialize CURRENT_PLAN.md
        plan_content = self._generate_plan_template(goal, phases or self.PHASES)
        self.plan_file.write_text(plan_content)

        # Add to .gitignore if in git repo
        self._update_gitignore()

        print(f"✅ Plan initialized at {self.working_dir}")
        print(f"   Goal: {goal}")
        print(f"   Phases: {', '.join(phases or self.PHASES)}")

    def _generate_plan_template(self, goal: str, phases: List[str]) -> str:
        """Generate the CURRENT_PLAN.md template."""
        timestamp = datetime.now().isoformat()

        template = f"""<!--
META: PLAN_IN_PROGRESS
If you are a new Claude instance reading this file, use the `plan` skill to resume this plan.
Command: Use the Skill tool with skill="plan" to continue from the current phase.
-->

# Current Plan

**Goal:** {goal}

**Status:** In Progress
**Current Phase:** {phases[0]}
**Created:** {timestamp}
**Last Updated:** {timestamp}

---

## Plan Metadata

```json
{{
  "goal": "{goal}",
  "phases": {json.dumps(phases)},
  "current_phase": "{phases[0]}",
  "current_phase_index": 0,
  "completed_phases": [],
  "started": "{timestamp}",
  "last_updated": "{timestamp}"
}}
```

---

## Phase Progress

"""

        for i, phase in enumerate(phases):
            status = "⏳ Current" if i == 0 else "⏸️ Pending"
            template += f"### {i+1}. {phase.title()} {status}\n\n"
            template += f"**Plan File:** `.plans/{phase}/plan.md`\n\n"
            template += "**Status:** Not started\n\n"
            template += "**Outputs:**\n- None yet\n\n"
            template += "---\n\n"

        template += """
## Phase Transition Protocol

When transitioning between phases:

1. **Complete Current Phase**
   - Finalize all outputs in `.plans/<phase>/`
   - Update phase status and outputs in this file
   - Mark phase as completed in metadata

2. **Prepare Next Phase**
   - Read next phase plan from `.plans/<next_phase>/plan.md`
   - Review only essential outputs from previous phases
   - Do NOT load full context from previous phases

3. **Update Plan File**
   - Update current_phase in metadata
   - Add completed phase to completed_phases
   - Update last_updated timestamp
   - Update phase progress section

---

## Notes

- Each phase should maintain its own isolated context in `.plans/<phase>/`
- Phase outputs should be clearly defined and minimal
- Use knowledge-base for research artifacts that multiple phases may reference
- Avoid loading unnecessary context between phases
"""

        return template

    def _update_gitignore(self) -> None:
        """Add plan files to .gitignore if in a git repository."""
        git_dir = self.working_dir / ".git"
        if not git_dir.exists():
            return

        gitignore = self.working_dir / ".gitignore"
        entries = ["CURRENT_PLAN.md", ".plans/"]

        existing_content = ""
        if gitignore.exists():
            existing_content = gitignore.read_text()

        needs_update = False
        for entry in entries:
            if entry not in existing_content:
                needs_update = True
                break

        if needs_update:
            with gitignore.open("a") as f:
                if existing_content and not existing_content.endswith("\n"):
                    f.write("\n")
                f.write("\n# Plan skill files\n")
                for entry in entries:
                    if entry not in existing_content:
                        f.write(f"{entry}\n")

            print("✅ Updated .gitignore with plan files")

    def get_current_state(self) -> Dict:
        """Extract current plan state from CURRENT_PLAN.md."""
        if not self.plan_file.exists():
            raise FileNotFoundError("No CURRENT_PLAN.md found")

        content = self.plan_file.read_text()

        # Extract JSON metadata
        import re
        json_match = re.search(r'```json\n(.*?)\n```', content, re.DOTALL)
        if not json_match:
            raise ValueError("Could not find metadata in CURRENT_PLAN.md")

        metadata = json.loads(json_match.group(1))
        return metadata

    def update_phase(self, phase: str, status: str, outputs: Optional[List[str]] = None) -> None:
        """Update the status of a specific phase."""
        if not self.plan_file.exists():
            raise FileNotFoundError("No CURRENT_PLAN.md found")

        content = self.plan_file.read_text()
        metadata = self.get_current_state()

        # Update metadata
        if status == "completed":
            if phase not in metadata["completed_phases"]:
                metadata["completed_phases"].append(phase)

            # Move to next phase
            current_idx = metadata["current_phase_index"]
            if current_idx + 1 < len(metadata["phases"]):
                metadata["current_phase_index"] = current_idx + 1
                metadata["current_phase"] = metadata["phases"][current_idx + 1]

        metadata["last_updated"] = datetime.now().isoformat()

        # Update JSON in content
        import re
        json_str = json.dumps(metadata, indent=2)
        content = re.sub(
            r'```json\n.*?\n```',
            f'```json\n{json_str}\n```',
            content,
            flags=re.DOTALL
        )

        # Update phase section
        phase_pattern = rf'(### \d+\. {phase.title()}) .*?\n'
        if status == "completed":
            content = re.sub(phase_pattern, rf'\1 ✅ Completed\n', content)
        elif status == "in_progress":
            content = re.sub(phase_pattern, rf'\1 ⏳ Current\n', content)

        # Update outputs if provided
        if outputs:
            outputs_text = "\n".join(f"- {output}" for output in outputs)
            content = re.sub(
                rf'(### \d+\. {phase.title()}.*?\*\*Outputs:\*\*\n)- None yet',
                rf'\1{outputs_text}',
                content,
                flags=re.DOTALL
            )

        self.plan_file.write_text(content)
        print(f"✅ Updated phase: {phase} -> {status}")

    def cleanup(self) -> None:
        """Remove all plan files after completion."""
        import shutil

        if self.plans_dir.exists():
            shutil.rmtree(self.plans_dir)
            print(f"✅ Removed {self.plans_dir}")

        if self.plan_file.exists():
            self.plan_file.unlink()
            print(f"✅ Removed {self.plan_file}")

        print("✅ Plan cleanup completed")


def main():
    """CLI interface for the orchestrator."""
    import argparse

    parser = argparse.ArgumentParser(description="Plan Orchestrator")
    parser.add_argument("--dir", default=".", help="Working directory")

    subparsers = parser.add_subparsers(dest="command", required=True)

    # Initialize command
    init_parser = subparsers.add_parser("init", help="Initialize a new plan")
    init_parser.add_argument("goal", help="Plan goal")
    init_parser.add_argument("--phases", nargs="+", help="Custom phases")

    # Status command
    subparsers.add_parser("status", help="Show current plan status")

    # Update command
    update_parser = subparsers.add_parser("update", help="Update phase status")
    update_parser.add_argument("phase", help="Phase name")
    update_parser.add_argument("status", choices=["in_progress", "completed"])
    update_parser.add_argument("--outputs", nargs="+", help="Phase outputs")

    # Cleanup command
    subparsers.add_parser("cleanup", help="Clean up plan files")

    args = parser.parse_args()
    orchestrator = PlanOrchestrator(args.dir)

    if args.command == "init":
        orchestrator.initialize_plan(args.goal, args.phases)
    elif args.command == "status":
        state = orchestrator.get_current_state()
        print(json.dumps(state, indent=2))
    elif args.command == "update":
        orchestrator.update_phase(args.phase, args.status, args.outputs)
    elif args.command == "cleanup":
        orchestrator.cleanup()


if __name__ == "__main__":
    main()
