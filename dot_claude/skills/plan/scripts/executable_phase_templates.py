#!/usr/bin/env python3
"""
Phase Templates - Provides structured templates for each phase type.

Each template defines:
- Phase objectives
- Required inputs
- Expected outputs
- Memory management guidelines
"""

from pathlib import Path
from typing import Dict


PHASE_TEMPLATES: Dict[str, str] = {
    "research": """# Research Phase

## Objective
Gather and document information needed to understand the problem space and plan the solution.

## Inputs
- Project goal from CURRENT_PLAN.md
- Any user-provided context or requirements

## Outputs
- `research_findings.md` - Key findings and insights
- `.plans/knowledge-base/*.md` - Reference documentation for future phases
- `phase_summary.md` - Concise summary of research outcomes

## Memory Management
- Store comprehensive documentation in knowledge-base for cross-phase reference
- Keep phase_summary.md under 500 words for efficient loading
- Avoid loading full research in future phases unless explicitly needed

## Process
1. **Identify Information Needs**
   - What needs to be understood?
   - What existing code/systems are relevant?
   - What constraints exist?

2. **Gather Information**
   - Search codebase for relevant patterns
   - Read existing documentation
   - Identify dependencies and integration points

3. **Document Findings**
   - Create structured documentation in knowledge-base
   - Note critical insights in research_findings.md
   - Write phase_summary.md for orchestrator

4. **Prepare for Planning Phase**
   - List key considerations for planning
   - Identify potential approaches
   - Note constraints and requirements

## Completion Criteria
- [ ] All critical information gathered
- [ ] Findings documented in knowledge-base
- [ ] phase_summary.md created
- [ ] Ready to begin planning phase
""",

    "planning": """# Planning Phase

## Objective
Design the solution approach based on research findings.

## Inputs
- `../ research/phase_summary.md` - Research outcomes (load this, NOT full research)
- Project goal from CURRENT_PLAN.md

## Outputs
- `plan.md` - Detailed implementation plan
- `architecture.md` - System design and architecture decisions
- `phase_summary.md` - Concise plan overview

## Memory Management
- Only load research phase_summary.md, not full research context
- Keep architecture decisions concise and focused
- Store detailed technical specs in separate files

## Process
1. **Review Research Summary**
   - Load only research/phase_summary.md
   - Identify key constraints and requirements

2. **Design Solution**
   - Define architecture and approach
   - Break down into implementable steps
   - Identify dependencies and order

3. **Create Implementation Plan**
   - Write step-by-step plan in plan.md
   - Document architecture decisions
   - List required resources

4. **Write Phase Summary**
   - Summarize approach in under 300 words
   - List critical decisions
   - Note key files/components

## Completion Criteria
- [ ] Clear implementation plan created
- [ ] Architecture documented
- [ ] phase_summary.md created
- [ ] Ready for revision phase
""",

    "revision": """# Revision Phase

## Objective
Review and refine the plan, identify gaps or improvements.

## Inputs
- `../planning/phase_summary.md` - Planning outcomes
- `../planning/plan.md` - Full implementation plan

## Outputs
- `review_notes.md` - Review findings and recommendations
- `revised_plan.md` - Updated plan (if changes needed)
- `phase_summary.md` - Summary of revisions

## Memory Management
- Load planning outputs for review
- Keep revision notes focused on changes only
- Avoid re-documenting unchanged aspects

## Process
1. **Review Plan**
   - Load planning phase outputs
   - Check for completeness and feasibility
   - Identify gaps or risks

2. **Provide Feedback**
   - Document concerns in review_notes.md
   - Suggest improvements
   - Validate against requirements

3. **Revise if Needed**
   - Update plan based on feedback
   - Create revised_plan.md if changes made
   - Otherwise, approve existing plan

4. **Write Phase Summary**
   - Summarize review outcomes
   - List key changes (if any)
   - Confirm plan is ready

## Completion Criteria
- [ ] Plan reviewed thoroughly
- [ ] Feedback documented
- [ ] Revisions made (if needed)
- [ ] phase_summary.md created
- [ ] Ready for building phase
""",

    "building": """# Building Phase

## Objective
Implement the solution according to the plan.

## Inputs
- `../revision/phase_summary.md` - Final plan approval
- `../planning/plan.md` - Implementation plan
- Knowledge base references as needed

## Outputs
- Implementation artifacts (code, configs, etc.)
- `implementation_log.md` - What was built and any deviations
- `phase_summary.md` - Summary of implementation

## Memory Management
- Load only plan and revision summary initially
- Reference knowledge base files on-demand
- Do NOT load full research or planning context
- Keep implementation_log focused on deviations and key decisions

## Process
1. **Load Plan**
   - Read planning/plan.md
   - Read revision/phase_summary.md
   - Prepare implementation checklist

2. **Execute Implementation**
   - Follow plan step-by-step
   - Document deviations in implementation_log.md
   - Reference knowledge base as needed

3. **Track Progress**
   - Update implementation_log with completed steps
   - Note any issues or changes from plan
   - Document new decisions

4. **Write Phase Summary**
   - Summarize what was built
   - Note any deviations from plan
   - List artifacts created

## Completion Criteria
- [ ] All planned items implemented
- [ ] Deviations documented
- [ ] implementation_log.md created
- [ ] phase_summary.md created
- [ ] Ready for validation phase
""",

    "validation": """# Validation Phase

## Objective
Verify the implementation meets requirements and works correctly.

## Inputs
- `../building/phase_summary.md` - Implementation summary
- `../building/implementation_log.md` - Implementation details
- Project goal from CURRENT_PLAN.md

## Outputs
- `validation_results.md` - Test results and verification
- `issues.md` - Any problems found
- `phase_summary.md` - Summary of validation

## Memory Management
- Load building phase summary
- Reference implementation_log for details
- Do NOT load full building context
- Keep validation results structured and scannable

## Process
1. **Review Implementation**
   - Load building/phase_summary.md
   - Understand what was built

2. **Execute Validation**
   - Run tests if applicable
   - Verify against requirements
   - Check for issues or gaps

3. **Document Results**
   - Write validation_results.md
   - List any issues in issues.md
   - Note pass/fail for each requirement

4. **Write Phase Summary**
   - Summarize validation outcomes
   - List critical issues (if any)
   - Confirm completion or note needed fixes

## Completion Criteria
- [ ] Validation executed
- [ ] Results documented
- [ ] Issues identified (if any)
- [ ] phase_summary.md created
- [ ] Ready for cleanup or iteration
""",

    "cleanup": """# Cleanup Phase

## Objective
Finalize the project and optionally remove plan artifacts.

## Inputs
- All phase summaries
- CURRENT_PLAN.md

## Outputs
- `final_summary.md` - Complete project summary
- Optional: Plan files removed (if user confirms)

## Memory Management
- Load only phase summaries, not full context
- Create final summary from summaries
- Minimal context needed for cleanup

## Process
1. **Review All Phase Summaries**
   - Load each phase/phase_summary.md
   - Understand complete project flow

2. **Create Final Summary**
   - Write final_summary.md with:
     - Project goal
     - What was accomplished
     - Key decisions and outcomes
     - Final artifacts and locations

3. **Confirm Cleanup**
   - Ask user if plan files should be removed
   - If yes, run cleanup utility
   - If no, keep plan files for reference

4. **Complete Project**
   - Mark plan as completed in CURRENT_PLAN.md
   - Move final_summary.md to project root (optional)

## Completion Criteria
- [ ] final_summary.md created
- [ ] User consulted about cleanup
- [ ] Plan marked complete
- [ ] Project finalized
"""
}


def create_phase_plan(phase: str, output_path: Path) -> None:
    """Create a phase plan file from template."""
    if phase not in PHASE_TEMPLATES:
        raise ValueError(f"Unknown phase: {phase}")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(PHASE_TEMPLATES[phase])
    print(f"✅ Created phase plan: {output_path}")


def main():
    """CLI interface for phase templates."""
    import argparse

    parser = argparse.ArgumentParser(description="Generate phase plan templates")
    parser.add_argument("phase", choices=list(PHASE_TEMPLATES.keys()), help="Phase name")
    parser.add_argument("output", help="Output file path")

    args = parser.parse_args()
    create_phase_plan(args.phase, Path(args.output))


if __name__ == "__main__":
    main()
