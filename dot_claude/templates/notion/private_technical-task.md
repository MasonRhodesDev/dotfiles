# Technical Task Specification Template

## Use Case
Technical implementation tasks requiring clear specifications, definition of done, and testing procedures. Ideal for feature development, bug fixes, or infrastructure changes.

**Target Length:** 800–1200 words
**Tone:** Formal, imperative, technical
**Primary Audience:** Developers, QA engineers, technical leads

---

## Template Structure

```markdown
# [Icon] [Task Title with Ticket ID]

### Task description
[Brief overview of what needs to be done and why, 2–3 sentences]

[Optional: Link to parent epic or related documentation]

---

### Technical Definition of done
- [ ] Specific implementation requirement 1
  - [ ] Sub-requirement with technical details
  - [ ] Code/logic reference with links to GitHub
- [ ] Specific implementation requirement 2
- [ ] Edge cases handled
- [ ] Tests written/updated

[Optional: Technical notes, implementation details, code snippets]

---

## How to test
- [ ] Setup prerequisite condition
- [ ] Execute test action
- [ ] Verify expected behavior
- [ ] Validate edge case

*Use this as a note for the QA team on what to pay attention to.*

---

[Optional: QA STATUS section with results]

[Optional: Screenshots/evidence of testing]
```

---

## Filling Instructions

### 1. Title
- **Format:** `[Icon] [Task Title with Ticket ID]`
- **Icons:** 🪨 for implementation tasks, 🪲 for bugs
- **Ticket ID:** Include LMD- prefix or relevant ticket system
- **Example:** `🪨 [LMD-23242] Update GLP-1 protocol`

### 2. Task Description
- **Length:** 2–3 sentences max
- **Content:** Focus on "what" and "why"
- **Links:** Reference parent epic or related documentation
- **Clarity:** Avoid vague language—use "must", "should", or "will"

### 3. Technical Definition of Done
- **Format:** Checkbox list with nested sub-items
- **Specificity:** Each item must be measurable and verifiable
- **GitHub Links:** Include commit/PR links for traceability
- **Completeness:** Mark items `[x]` when done

### 4. How to Test
- **Audience:** Written for QA team, not developers
- **User-Facing:** Focus on external validation, not implementation details
- **Completeness:** 4–6 test cases per section
- **Clarity:** Include prerequisites and expected outcomes

### 5. QA Status (Optional)
- **Format:** "QA STATUS: PASSED / BLOCKED / IN PROGRESS - [Tester Name]"
- **Evidence:** Add screenshots showing validation results
- **Blockers:** Link to duplicate issues or blocking tasks

---

## Metadata / Properties to Set

**Essential Properties:**
- **Task name:** Same as page title
- **Status:** In Progress, In Review, Testing, Pushed to production
- **Responsible/Assignee:** Primary developer(s)
- **Task ID:** Unique identifier (e.g., LMD-23242)
- **Priority:** Urgent, High, Normal, Low

**Common Properties:**
- **Sprint:** Link to sprint database entry
- **Platform:** Backend, Frontend, Mobile, QA, DevOps
- **Tracker:** Feature, Bug, Chore
- **Due Date:** Target completion date
- **Epic relation:** Link to parent epic
- **GitHub PR:** URL to pull request

**Conditional Properties:**
- **Manual testing required:** Checkbox (yes/no)
- **DevOps involvement:** Checkbox (yes/no)
- **Tested by:** Person property for QA assignment
- **Release Date:** When deployed to production
- **Severity Levels:** P1–P4 for bugs

---

## Tone Guidelines

### Voice
- **Direct and Imperative:** "Create...", "Update...", "Ensure..."
- **Present Tense:** For requirements ("Lab orders should not be created")
- **Past Tense:** For completed items ("Implemented in [GitHub link]")
- **Precision:** Avoid ambiguity—use RFC 2119 language (MUST, SHOULD, MAY)

### Examples
- ✅ "Remove lab order creation based on patient BMI"
- ✅ "Lab orders should not be created during onboarding"
- ❌ "Maybe we don't need labs?" (too vague)
- ❌ "Try to ensure the API works" (imprecise)

---

## Visual Design Patterns

### Section Breaks
- Use `---` (horizontal rule) to separate major sections
- Improves readability for QA and reviewing stakeholders

### Code Blocks
- Use language-specific syntax highlighting
- Include context comments explaining purpose

```javascript
// Example: Update onboarding logic
const shouldCreateLabs = (bmi) => bmi < 25; // No labs for BMI >= 25
```

### Callouts (Optional)
- **🔴 Red:** Critical blockers
- **🟡 Yellow:** Warnings or important caveats
- **💡 Gray:** Tips or access requirements
- **✅ Green:** Success criteria

---

## Quick Checklist

Before publishing:

- [ ] **Title** includes icon, ticket ID, and clear subject
- [ ] **Task description** is 2–3 sentences with context links
- [ ] **Definition of Done** is specific and measurable
  - [ ] Sub-items reference GitHub commits/PRs where applicable
  - [ ] All items are checkboxes, not prose
- [ ] **Testing section** is written for QA team
  - [ ] Prerequisites are listed
  - [ ] Expected behaviors are clear
  - [ ] Edge cases are covered
- [ ] **Properties** are set: Status, Assignee, Priority, Sprint
- [ ] **Related links** point to parent epic, dependencies
- [ ] **No vague language:** All requirements are specific

---

## Real-World Example

```markdown
# 🪨 [LMD-23242] Update GLP-1 protocol - No longer required to create lab orders

### Task description
Per [Epic: GLP-1 Protocol Updates], we no longer need to create labs for patients with BMI 27–30 without co-morbidities, as previously implemented in [Task: Initial BMI Lab Requirements]. This change reduces unnecessary lab work orders during onboarding.

---

### Technical Definition of done
- [x] No lab orders or request tasks are created during onboarding for patients with BMI 25 or higher
  - [x] Remove `labs_order_creation_on_bmi` logic in `onboarding.ts`
  - [x] Hide `medical_conditions_based_on_bmi` MIF question for WM users
  - [x] Hide `labs` MIF question for WM users
  - [x] [GitHub commit: abc123def456](https://github.com/example/repo/commit/abc123)
- [x] Edge cases handled: Users updating BMI post-onboarding should not trigger retroactive labs
- [x] Unit tests written for `shouldCreateLabs()` utility
- [x] E2E tests updated in `onboarding.spec.ts`

---

## How to test
- [ ] Create WM user with BMI between 27–30
- [ ] Verify BMI-related question does not display during onboarding
- [ ] Verify Lab work question does not display during onboarding
- [ ] Verify no Labs order is created in the task list
- [ ] Verify no Request task is created for lab work
- [ ] Test edge case: User with BMI 26 after onboarding should not trigger retroactive labs

*QA Note: Focus on ensuring the onboarding flow completes without lab-related questions or orders.*

---

QA STATUS: PASSED - [Tester Name], Feb 3, 2026

[Screenshot: Onboarding flow without lab question](image-url)
[Screenshot: Task list verification - no labs order](image-url)
```

---

**Template Version:** 1.0
**Last Updated:** February 3, 2026
**Based on:** Notion Page Analysis & Template Guide
