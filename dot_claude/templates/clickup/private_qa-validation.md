# ClickUp Template: QA/Validation Task

**Use for:** Testing tasks, validation work, QA-specific tickets
**Target length:** 400-1,500 characters
**Tone:** Structured, methodical, with placeholder sections

---

## Template

```markdown
[Component] - [Feature Name]

Requested by:
[Brief summary of what needs validation]

Request:
[Specific testing requirements if any - or leave empty until details provided]

Result:
[Empty - to be filled after testing completes]

Where to test:
This will be updated when task is set to READY FOR QA

Context:
[Detailed breakdown of feature components, sub-tasks, or acceptance criteria being validated]

Integration(s):
[List of systems or components involved]

[Optional: Testing checklist]
```

---

## Filling Instructions

**Title:**
- Include component prefix: `[QAI]`, `[AP - QA]`, etc.
- State what's being validated
- Format: `[Component] - [Feature or Epic Name]`

**Requested By:**
- One-line summary of validation need
- Can reference ticket: "Per [Ticket #123]"
- Or describe: "Validate social sign-in feature"

**Request:**
- Specific testing asks if known
- Can be empty initially - filled in when task moves to READY FOR QA
- Examples: "Focus on edge cases", "Validate across all platforms"

**Result:**
- Leave empty initially
- Fill after testing: "PASSED", "FAILED - see issues", "BLOCKED"
- Include summary of findings

**Where to Test:**
- Placeholder: "This will be updated when task is set to READY FOR QA"
- Update with specific environment when ready
- Examples: "Stage environment", "QA-2 instance", "Feature branch deploy"

**Context:**
- Detailed breakdown of what's being tested
- Reference parent ticket or epic
- List sub-tasks or components
- Include acceptance criteria from dev ticket

**Integration(s):**
- Systems involved in this feature
- External APIs or services
- Database changes
- Third-party integrations

---

## Actual Examples

### Example 1: Feature Validation

```markdown
[QAI] - MVP - SSO Authentication

Requested by:
Validate social sign-in (Google, Facebook) and social log-in feature implementation

Request:
Test across web and mobile platforms, verify token handling and account linking

Result:
[To be filled after testing]

Where to test:
This will be updated when task is set to READY FOR QA

Context:
Per [Epic: SSO Authentication] validate:
- Google sign-in flow
  - New user registration via Google
  - Existing user login via Google
  - Account linking for users with email/password
- Facebook sign-in flow
  - New user registration via Facebook
  - Existing user login via Facebook
  - Account linking
- Token refresh and expiration handling
- Error scenarios (declined permissions, invalid tokens)

Integration(s):
- Google OAuth 2.0 API
- Facebook Login API
- Auth0 integration
- User database (account linking logic)
```

### Example 2: Bug Fix Validation

```markdown
[AP - QA] Validate Bug Fix - Manage Prospects Offer Change

Requested by:
Validate fix for bug where offer updates incorrectly when changing Product Config

Request:
Verify offer remains stable when updating Product Config, test with multiple offer types

Result:
[To be filled]

Where to test:
This will be updated when task is set to READY FOR QA

Context:
Bug was introduced in feature allowing new Product Configs to load different offers.
Fix removed onChange trigger. Need to validate:

- [ ] Load Manage Prospects page
- [ ] Select Product Config A with Offer X
- [ ] Change to Product Config B with Offer Y
- [ ] Verify Offer Y loads correctly
- [ ] Verify Offer X is not partially retained
- [ ] Test with 3-4 different Product Config + Offer combinations

Integration(s):
- Admin Portal
- Product Config service
- Offer management system
```

### Example 3: Release Validation

```markdown
[QAI] Validate Feature Request - Support Testo Rx Changes

Requested by:
Validate Testo Rx product changes for upcoming release

Request:
Full regression on Testo Rx flow including new dosage options and prescription logic

Result:
[To be filled]

Where to test:
This will be updated when task is set to READY FOR QA

Context:
Validate changes to Testo Rx product:
1. New dosage options (100mg, 200mg) display correctly in onboarding
2. Prescription logic updated for higher dosages
3. Pricing reflects new tiers
4. Existing patients can upgrade/downgrade dosage
5. Lab requirements unchanged
6. Shipping/fulfillment updated for new packaging

Testing checklist:
- [ ] New patient onboarding flow
- [ ] Existing patient upgrade path
- [ ] Prescription generation
- [ ] Pricing calculation
- [ ] Order processing
- [ ] Admin portal updates

Integration(s):
- Patient onboarding system
- Prescription generation
- Payment processing
- Fulfillment system
- Admin portal
```

---

## Metadata to Set

**Tags:** QA, component tag, platform tag if applicable
**Priority:** Match priority of parent feature/bug
**Story Points:** Usually 1-3 for QA tasks
**List:** QA list or sprint list
**Assignee:** QA team member
**Custom Fields:**
- Manual testing required: Yes
- Related ticket: Link to dev ticket
- Platform: Web/Mobile/Both

---

## Tone Guidelines

**DO:**
- Use structured format with clear sections
- Include placeholder text for sections filled later
- Reference parent tickets and epics
- Break down testing into logical components
- Use checklists for testing steps
- List all integrations/systems involved

**DON'T:**
- Write vague testing requirements
- Skip context about what changed
- Forget to link parent ticket
- Leave "Where to test" without placeholder
- Omit integration details

---

## Length Guidelines

**400-800 chars:** Minimum for simple validation
**800-1,200 chars:** Good for standard feature testing
**1,200-1,500 chars:** Complex features with multiple components

QA tickets tend toward detail - err on the side of more context rather than less.

---

## Progressive Disclosure Pattern

QA tickets use **progressive disclosure** - sections are placeholders that get filled as work progresses:

**Initial Creation:**
- Context and Integration(s) are filled
- Request may be empty or brief
- Result is empty
- Where to test has placeholder

**When Moved to READY FOR QA:**
- Where to test updated with environment
- Request updated with specific testing instructions
- Testing checklist added if not present

**After Testing:**
- Result filled with outcome and summary
- Issues/bugs linked if found
- Screenshots/evidence attached

---

## When to Use This Template

Use QA-validation template when:
- Testing existing functionality
- Validating bug fixes
- Release validation
- Feature sign-off required
- Dedicated QA task separate from dev work

Use complex-feature template when:
- Dev ticket includes QA as acceptance criteria
- Single ticket covers dev + QA
- QA is not separately tracked

---

## Quick Checklist

Before submitting:
- [ ] Title includes component and feature name
- [ ] Requested by is clear
- [ ] Context explains what's being tested
- [ ] Integration(s) listed
- [ ] Where to test has placeholder
- [ ] Result section empty (to be filled)
- [ ] Parent ticket linked if applicable
- [ ] Tags: QA + component
- [ ] Assignee: QA team member
