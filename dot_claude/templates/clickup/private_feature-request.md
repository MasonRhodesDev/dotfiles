# ClickUp Template: Feature Request

**Use for:** User-facing features or workflow improvements with business value focus
**Target length:** 300-1,000 characters
**Tone:** Narrative, contextual, business-focused

---

## Template

```markdown
[Component] Feature Name

The issue: [Describe current workflow in detail, focusing on user pain points and friction]

The problem is that [specific negative consequence or impact on users/business]

Our solution is to [describe proposed solution with focus on workflow improvement and business value]
```

---

## Alternative Template (Structured)

```markdown
Feature: [Feature Name]

## Current Workflow

[Describe how users currently accomplish this task - include friction points]

## Problem

[Specific negative consequences, business impact, user frustration]

## Proposed Solution

[Describe the improvement - focus on user experience and business value, not technical implementation]

## Expected Benefits

- Benefit 1 with metric if possible
- Benefit 2
- Benefit 3
```

---

## Filling Instructions

**Title:**
- Use "Feature:" prefix or component prefix
- Clear, descriptive name of the feature
- Action-oriented: "Add...", "Enable...", "Improve..."

**The Issue:**
- Describe current state from user perspective
- Focus on pain points and friction
- Be specific about the workflow
- Use present tense

**The Problem:**
- State the negative consequence clearly
- Connect to business impact or user frustration
- Quantify if possible: "Adds 5 minutes to each request"
- Make the "why this matters" explicit

**Our Solution:**
- Describe the proposed improvement
- Focus on workflow change, not technical details
- Explain how it addresses the problem
- Highlight business value

---

## Actual Examples

### Example 1: Narrative Format

```markdown
Feature: Combine Renewal + RX Change Request

The issue: Currently when a representative at the call center processes a renewal and
the patient would like an RX change, they answer questions with the patients and then
click 'update'.

The problem is that the DR will frequently see the renewal for the previous medication,
write a script, and then become annoyed when they need to write a new script for a
different medication shortly thereafter.

Our solution is to combine these into a single workflow where the RX change is processed
as part of the renewal request, so the DR sees the updated medication information when
writing the renewal script.
```

### Example 2: Structured Format

```markdown
Feature: Add Self-Service Account Cancellation

## Current Workflow

Patients must call customer support to cancel subscriptions, wait on hold (avg 15min),
and go through retention script before cancellation is processed.

## Problem

- 40% of cancellation calls occur outside business hours → frustrated users
- Support team spends 60% of time on cancellations → high operational cost
- Retention script rarely succeeds (8% save rate) → wastes time

## Proposed Solution

Add self-service cancellation flow in patient portal with:
- Immediate cancellation option
- Optional feedback survey
- Automatic offer of pause/discount before final cancel
- Email confirmation with reactivation link

## Expected Benefits

- Reduce support call volume by ~35%
- Improve user satisfaction (24/7 availability)
- Maintain retention opportunities via automated offer
- Free support team for higher-value interactions
```

---

## Metadata to Set

**Tags:** Feature area, affected component
**Priority:** Based on business impact
- High if significant user pain or revenue impact
- Normal for standard improvements
- Low for nice-to-haves
**Story Points:** Usually 3-5 for features
**List:** Feature requests or backlog list
**Assignee:** Product manager or feature owner
**Custom Fields:**
- Brand (if brand-specific)
- Requested By (if customer request)

---

## Tone Guidelines

**DO:**
- Write in narrative form - tell the story
- Focus on user perspective and business value
- Explain current pain points clearly
- Use present tense for current state
- Use future tense or imperative for solution
- Quantify impact when possible

**DON'T:**
- Jump into technical implementation
- Assume everyone knows the context
- Write vague problem statements
- Skip the "why this matters"
- Use technical jargon unnecessarily

---

## Length Guidelines

**300-500 chars:** Minimum for clear feature request
**500-800 chars:** Sweet spot - enough context without over-explaining
**800-1,000 chars:** Maximum before it becomes comprehensive spec

If longer than 1,000 chars, consider:
- Is this actually multiple features?
- Should this use the complex-feature template instead?
- Can you move technical details to a separate section?

---

## When to Use This Template

Use feature-request when:
- Focus is on user/business value over technical implementation
- Request originated from users, product team, or stakeholders
- Workflow improvement is the primary goal
- Need to justify "why" before "how"

Use complex-feature template when:
- Need detailed technical specification
- Multiple components involved
- Primarily technical audience
- Implementation details are critical upfront

---

## Quick Checklist

Before submitting:
- [ ] Title clearly states the feature
- [ ] Current workflow/issue described
- [ ] Problem/impact explicitly stated
- [ ] Solution focused on user benefit
- [ ] Business value is clear
- [ ] Length: 300-1,000 chars
- [ ] Priority reflects business impact
- [ ] Appropriate list/backlog selected
