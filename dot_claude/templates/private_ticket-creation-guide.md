# Ticket Creation Master Guide

**Version:** 1.0
**Last Updated:** 2026-02-03

Quick reference for creating tickets in ClickUp and Notion with appropriate format, tone, and structure.

---

## Quick Start

**Before creating a ticket:**
1. Identify platform (ClickUp or Notion)
2. Determine ticket type (see decision tree below)
3. Select appropriate template
4. Calibrate tone (organizational vs personal)
5. Fill in sections, adjust length as needed

---

## Decision Tree: Template Selection

```
What are you creating?

├─ ClickUp Ticket
│  ├─ Complex development feature (multiple files, comprehensive spec)
│  │  → Use: clickup/complex-feature.md (2,000-8,000 chars)
│  │
│  ├─ Simple bug fix (terse, direct)
│  │  → Use: clickup/bug-fix.md (50-300 chars)
│  │
│  ├─ Feature request (business-focused, narrative)
│  │  → Use: clickup/feature-request.md (300-1,000 chars)
│  │
│  ├─ Marketing/creative work (informal, brief)
│  │  → Use: clickup/marketing-creative.md (200-800 chars)
│  │
│  └─ QA/validation task (structured, placeholder sections)
│     → Use: clickup/qa-validation.md (400-1,500 chars)
│
└─ Notion Page
   ├─ Technical task with implementation details
   │  → Use: notion/technical-task.md (800-1200 words)
   │
   ├─ Process documentation or guidelines
   │  → Use: notion/process-doc.md (1500-3000 words)
   │
   ├─ Meeting notes with action items
   │  → Use: notion/meeting-notes.md (300-800 words)
   │
   ├─ Reference documentation (API, database)
   │  → Use: notion/reference-doc.md (varies)
   │
   └─ Bug report or issue tracking
      → Use: notion/bug-report.md (400-1000 words)
```

---

## Tone Calibration Matrix

### Understanding the Spectrum

**Formal/Organizational** ←→ **Casual/Personal**

Templates default to **organizational norms** (left side). Use the calibration guide below to shift toward your personal style (right side) when appropriate.

### When to Use Which Tone

| Context | Formal (Org Standard) | Casual (Your Style) |
|---------|----------------------|-------------------|
| **Dev tickets** | ✅ Default - team expects comprehensive specs | Use for quick internal updates |
| **Bug fixes** | Default for tracking | ✅ Perfect match - terse, direct |
| **Code reviews** | Formal PR descriptions | ✅ Slack-style: "review? [link]" |
| **Status updates** | Formal project reports | ✅ Quick pings: "done", "fixed" |
| **External comms** | ✅ Client-facing, vendor coordination | Avoid |
| **Team chat** | Formal for important announcements | ✅ Default for day-to-day |

### Tone Shift Examples

**Formal → Casual Conversion:**

| Formal (Template) | Casual (Your Style) | Context |
|------------------|---------------------|---------|
| "Please review this pull request when you have a moment" | "review?" | Code review request |
| "I will investigate this issue and provide an update" | "looking into it now" | Status update |
| "The issue has been resolved and is ready for testing" | "fixed. good to test" | Completion notice |
| "Could you please take a look at this implementation?" | "Can you check [thing]?" | Request for help |
| "Thank you for bringing this to my attention" | "Thanks" or ✅ reaction | Acknowledgment |
| "Let me know if you have any questions" | "lmk if issues" or omit | Closing |

### Your Communication Patterns (from Slack Analysis)

**Core traits to maintain:**
- Ultra-concise: 1-2 sentences default
- Lowercase "i" acceptable
- Minimal punctuation at sentence ends
- Fragments over full sentences: "Yup", "For sure", "Sounds good"
- Links without ceremony: Just drop the URL
- Authentic reactions: "oh hell yeah", "no way", "lmao"
- Technical directness: Assume competence, use jargon freely
- Action-oriented: State what needs doing, skip the ceremony

**Anti-patterns (avoid these):**
- Corporate speak: "circling back", "touching base", "synergize"
- Excessive apologizing: "Sorry to bother you"
- Hedging: "I was just wondering if maybe you might..."
- Long paragraphs or verbose explanations
- Formal closings: "Regards", "Kindly"

---

## Platform-Specific Guidelines

### ClickUp

**Format Differences:**
- Uses `markdown_description` field for ticket body
- Supports custom fields (Brand, Indication, Requested By, etc.)
- Tags: Use sparingly (1-3 tags per ticket)
- Priorities: Urgent/High/Normal/Low (many have no priority)
- Story Points: 1-5 scale

**Title Patterns:**
- `[Prefix] Action-oriented title` (e.g., `[AP] Fix bug with...`)
- `Feature: Description` for new features
- `BRAND - CATEGORY - TYPE - Description` for marketing
- Keep 25-120 chars depending on complexity

**Markdown Usage:**
- Headers: `##` for sections, `###` for subsections
- Checklists: `- [ ]` for acceptance criteria
- Code blocks with language tags: ```typescript
- Emojis: Selective (✅ ❌ ⛔ ⚠️ for status only)

### Notion

**Format Differences:**
- Enhanced markdown with block types
- Database properties heavily used (Status, Owner, Sprint, Priority)
- Extensive cross-linking expected
- Icon prefixes in titles (🗺️ 🪲 💽 🧟 🪨)

**Title Patterns:**
- `[Icon] [Type/Context] Title`
- `[Ticket ID] Title - Description`
- `[Action] Subject - Object` pattern

**Markdown Usage:**
- Headers: `##` for primary sections (not # for title)
- Callouts for important info (💡 ⚠️ ❌ ✅)
- Properties set appropriately (always include Status, Owner)
- Tables for structured data (status definitions, assignments)
- Extensive use of `###` subsections

---

## Section Library: Reusable Blocks

### Acceptance Criteria (ClickUp/Notion)

```markdown
## Acceptance Criteria

### [Component/Area Name]
- [ ] Specific, testable criterion 1
- [ ] Specific, testable criterion 2
- [ ] Edge case handling
- [ ] Tests written/updated

### [Another Component]
- [ ] Criterion 1
- [ ] Criterion 2
```

**Guidelines:**
- Make criteria **testable** (avoid "works well", "looks good")
- Group by component or functional area
- Include tests as criteria for dev work
- Use nested bullets for sub-requirements

### Technical Approach (ClickUp Complex Feature)

```markdown
## Technical Approach

**Files to Modify:**
- `path/to/file1.ts` - [what changes]
- `path/to/file2.vue` - [what changes]

**Integration Points:**
- [System 1]: [how it integrates]
- [System 2]: [how it integrates]

**Dependencies:**
- Library 1 (version X.Y)
- Tool 2 (already integrated)
```

### Testing Instructions (ClickUp/Notion)

```markdown
## How to Test

- [ ] Setup: [prerequisite conditions]
- [ ] Action: [what to do]
- [ ] Verify: [expected behavior]
- [ ] Edge case: [specific scenario]

*Note for QA team: [any special attention areas]*
```

**Guidelines:**
- Write for QA team, not developers
- Include setup requirements
- State expected behavior explicitly
- Cover happy path + edge cases

### Bug Report Format (ClickUp Short)

```markdown
Reported By:
[Person or system]

Issue:
[1-2 sentence problem description]

Fix:
[1-2 sentence solution]
```

### Definition of Done (Notion Technical Tasks)

```markdown
### Technical Definition of Done

- [ ] High-level requirement
  - [ ] Implementation detail 1 with [GitHub link]
  - [ ] Implementation detail 2
  - [x] Completed sub-item
- [ ] Another requirement
- [ ] Edge cases handled
- [ ] Tests written/updated
```

### Process Steps (Notion Process Docs)

```markdown
## Workflow / Process Steps

**General Rules**
1. Rule 1 with clear directive
2. Rule 2 with consequences/reasoning
3. Rule 3 with examples

**Step-by-Step Process**

### [Step 1 Name]
Description of what happens at this stage

### [Step 2 Name]
Description with specific requirements
```

### Meeting Action Items (Notion)

```markdown
## **3. Action Items**

- **@Owner:** Specific action with clear deliverable
- **@Owner:** Another action with timeline if applicable
- **@Owner:** Third action
```

**Guidelines:**
- Always assign with @mention
- Be specific about deliverable
- Include timeline if time-sensitive

---

## Common Mistakes to Avoid

### ❌ Anti-Patterns

**Vague Descriptions:**
```
Bad:  "Make the app better"
Good: "Reduce API response time from 2s to <500ms by implementing Redis caching"

Bad:  "Fix the bug"
Good: "Fix: Remove onChange trigger so offer is not updated incorrectly"
```

**Ambiguous Acceptance Criteria:**
```
Bad:  "Should work well"
Good: "API returns 200 status within 500ms for standard queries"

Bad:  "Looks good"
Good: "UI matches Figma design (spec #123) with <2px variance"
```

**Missing Context:**
```
Bad:  "Update the config"
Good: "Update config.yml to use programCode instead of deprecated program param (per [Epic XYZ])"
```

**Wall of Text:**
```
Bad:  [Single 500-word paragraph]
Good: [Structured with headers, bullets, whitespace]
```

**Over-Explaining Simple Concepts:**
```
Bad:  "Git is a version control system that allows developers to track changes..."
Good: "Use feature branch workflow: feature/<ticket>-<description>"
```

### ✅ Best Practices

1. **Front-load information** - Most important details first
2. **Use structure** - Headers, bullets, whitespace for scanning
3. **Be specific** - File paths, function names, exact error messages
4. **Explain "why"** - For significant changes, provide business context
5. **Link related work** - Epic, parent task, dependencies, GitHub PRs
6. **Update progressively** - Fill placeholders as work progresses
7. **Assign ownership** - Use @mentions for accountability
8. **Match length to complexity** - Simple bugs stay brief, complex features are comprehensive

---

## Length Guidelines by Type

### ClickUp

| Ticket Type | Target Length | Character Count |
|-------------|---------------|-----------------|
| Bug Fix | Brief | 50-300 chars |
| Feature Request | Medium | 300-1,000 chars |
| Complex Feature | Comprehensive | 2,000-8,000+ chars |
| Marketing/Creative | Brief | 200-800 chars |
| QA/Validation | Medium | 400-1,500 chars |

### Notion

| Page Type | Target Length | Word Count |
|-----------|---------------|------------|
| Technical Task | Medium | 800-1,200 words |
| Process Doc | Comprehensive | 1,500-3,000 words |
| Meeting Notes | Brief-Medium | 300-800 words |
| Reference Doc | Varies | Depends on scope |
| Bug Report | Medium | 400-1,000 words |

**Optimal Section Lengths:**
- Paragraph: 2-4 sentences (50-100 words)
- Section: 150-300 words before next heading
- Checklist: 5-10 items before grouping under subsection

---

## Examples: Before & After

### Example 1: Bug Fix Ticket

**Before (Too Verbose):**
```
There seems to be an issue with the Manage Prospects feature where when users try
to change an offer, it's updating incorrectly. This was introduced in the recent
feature update that allows for new Product Configs to load different offers.
We should investigate and fix this as soon as possible. I think the problem might
be related to the onChange trigger.
```

**After (ClickUp Bug Template):**
```
[AP] Fix bug with Manage Prospects offer change

Reported By: QA Team

Issue:
Introduced a bug with the feature for new Product Configs loading a different offer

Fix:
Remove onChange trigger so that the offer is not updated
```

### Example 2: Feature Ticket

**Before (Missing Structure):**
```
We need to add upgrade content configuration to the product builder because right
now product managers can't easily manage the upgrade content that shows when users
try to upgrade their plans and this is causing problems.
```

**After (ClickUp Feature Template + Structure):**
```
Feature: Add Upgrade Content Configuration to Product Builder

## Overview

Enable product managers to configure upgrade content directly in the Builder
interface instead of requiring code changes.

## Background

**Current State:**
Upgrade content is hardcoded in UI components

**Problem:**
- PM cannot update upgrade messaging without developer involvement
- Slow iteration on upgrade copy
- No A/B testing capability

## Proposed Solution

Add new "Upgrade Content" configuration section in Product Builder with:
- Rich text editor for upgrade messaging
- Image upload for visual elements
- Preview before publishing

## Acceptance Criteria

### Builder UI
- [ ] New "Upgrade Content" tab in Product Builder
- [ ] Rich text editor integrated
- [ ] Image upload with preview
- [ ] Save/publish workflow

### API
- [ ] New endpoint: POST /api/products/{id}/upgrade-content
- [ ] Validation for required fields
- [ ] Version control for content changes

### Testing
- [ ] Manual: Create product, add upgrade content, verify display
- [ ] Edge case: Handle missing content gracefully
```

---

## Maintenance & Updates

### When to Update Templates

- Organizational patterns change (new sections become standard)
- Platform features change (new ClickUp fields, Notion properties)
- Team feedback identifies gaps or improvements
- New ticket types emerge

### How to Update

1. Review recent tickets to identify pattern shifts
2. Update template files in `/home/mason/.claude/templates/`
3. Update this guide with new patterns
4. Notify team of template changes (if shared)

### Version History

- **v1.0** (2026-02-03): Initial version based on 15+ ClickUp tickets, 15+ Notion pages, 50+ Slack messages

---

## Quick Reference Cards

### ClickUp Bug Fix Checklist
- [ ] [Component] prefix in title
- [ ] Reported By: [who]
- [ ] Issue: 1-2 sentences
- [ ] Fix: 1-2 sentences
- [ ] Total: <300 chars
- [ ] Tags: relevant component(1-3)
- [ ] Priority: if not normal

### ClickUp Complex Feature Checklist
- [ ] Feature: or [Prefix] in title
- [ ] Overview (2-3 sentences)
- [ ] Background/Problem Statement
- [ ] Proposed Solution with components
- [ ] Acceptance Criteria (checkbox format)
- [ ] Technical Approach (files, integrations)
- [ ] Testing Requirements
- [ ] Total: 2,000-8,000 chars
- [ ] Tags: component, feature area

### Notion Technical Task Checklist
- [ ] Icon + title with ticket ID
- [ ] Task description (2-3 sentences + link to parent)
- [ ] Technical Definition of Done (checkboxes)
- [ ] How to Test section
- [ ] Properties: Status, Owner, Sprint, Priority
- [ ] GitHub links in DoD items
- [ ] Total: 800-1,200 words

### Notion Process Doc Checklist
- [ ] Icon + title
- [ ] Callout with prerequisites
- [ ] Overview section
- [ ] Workflow/Process Steps (numbered)
- [ ] Status Definitions (table)
- [ ] Best Practices
- [ ] Properties: Type, Owner, Project
- [ ] Total: 1,500-3,000 words
- [ ] Mermaid flowchart if complex

---

## Template File Index

**ClickUp Templates:**
- `clickup/complex-feature.md` - Comprehensive dev work
- `clickup/bug-fix.md` - Quick fixes
- `clickup/feature-request.md` - Business-focused features
- `clickup/marketing-creative.md` - Campaign/creative work
- `clickup/qa-validation.md` - Testing tasks

**Notion Templates:**
- `notion/technical-task.md` - Implementation tasks
- `notion/process-doc.md` - Guidelines and workflows
- `notion/meeting-notes.md` - Team meetings
- `notion/reference-doc.md` - API/database/architecture
- `notion/bug-report.md` - Issue tracking

**Helper Tools:**
- `../skills/create-ticket/select-template.sh` - Interactive template selector
- `../skills/create-ticket/generate-ticket.sh` - Programmatic generation
- `../skills/create-ticket/tone-calibrate.sh` - Formal → casual conversion

---

**For assistance:** Refer to platform-specific analysis documents:
- ClickUp patterns: `~/.claude/plans/goofy-gathering-sedgewick-agent-af9521f.md`
- Notion patterns: `/home/mason/notion-page-analysis-template.md`
- Your communication style: `~/.claude/plans/goofy-gathering-sedgewick-agent-a29c5ed.md`
