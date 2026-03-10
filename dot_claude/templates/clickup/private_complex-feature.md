# ClickUp Template: Complex Feature

**Use for:** Development work spanning multiple files/components with detailed technical specification
**Target length:** 2,000-8,000 characters
**Tone:** Formal, technical, comprehensive

---

## Template

```markdown
[Prefix] Feature Title: Clear Description of What's Being Added

## Overview

[2-3 sentence summary of what this adds and why it matters. Link to related epic or parent issue if applicable.]

## Background

**Current State**

[What exists today - be specific about current implementation]

**Problem Statement**

[What pain points exist, what's missing, what friction this creates]

## Proposed Solution

### Component 1: [Name]
- [Details of what will be built]
- [Key features]
- [Integration points]

### Component 2: [Name]
- [Details of what will be built]
- [Technical approach]

[Add more components as needed]

## Acceptance Criteria

### [Component 1]
- [ ] Specific deliverable 1
- [ ] Specific deliverable 2
- [ ] Edge case handling
- [ ] Tests written/updated

### [Component 2]
- [ ] Specific deliverable 1
- [ ] Specific deliverable 2

### Testing
- [ ] Unit tests for [component]
- [ ] Integration tests for [workflow]
- [ ] Manual testing completed

## Technical Approach

**Files to Modify:**
- `path/to/file1.ts` - [what changes]
- `path/to/file2.vue` - [what changes]
- `path/to/file3.py` - [what changes]

**Integration Points:**
- [System 1]: [how it integrates]
- [System 2]: [how it integrates]

**Dependencies:**
- Library 1 (version X.Y)
- Tool 2 (already integrated)
- External API (if applicable)

## Testing Requirements

- [ ] Unit tests: [what components]
- [ ] Manual testing: [what scenarios]
- [ ] Edge cases: [specific conditions]
- [ ] Performance: [if applicable, metrics to validate]

## Related Links

- Parent Epic: [link]
- Design Spec: [link]
- GitHub Issue: [link]
```

---

## Filling Instructions

**Overview:**
- State WHAT and WHY in 2-3 sentences
- Link to parent epic or related work immediately

**Background:**
- Current State: Describe existing implementation specifically
- Problem Statement: Focus on friction, pain points, business impact

**Proposed Solution:**
- Break into logical components (UI, API, Database, etc.)
- Each component gets its own subsection
- Be specific about what will be built

**Acceptance Criteria:**
- Group by component or functional area
- Make each criterion testable and specific
- Include tests as acceptance criteria
- Use nested bullets for sub-requirements

**Technical Approach:**
- List specific files with brief description of changes
- Identify integration points with other systems
- Note dependencies (libraries, tools, services)

**Testing Requirements:**
- Cover unit, integration, manual testing
- Specify edge cases to validate
- Include performance criteria if relevant

---

## Examples of Good Criteria

✅ **Specific and testable:**
- "API returns 200 status for valid requests with response time <500ms"
- "UI matches Figma design (spec #123) with <2px variance"
- "Error handling displays user-friendly message for 400/500 errors"

❌ **Vague or untestable:**
- "Should work well"
- "Looks good"
- "Handles errors properly"

---

## Metadata to Set

**Tags:** 1-3 relevant tags (component name, feature area, tech stack)
**Priority:** Only if not Normal (Urgent/High/Low)
**Story Points:** Estimate 1-5 (complex features typically 3-5)
**List:** Appropriate list in your space
**Assignee:** Yourself or team member
**Sprint:** Current or planned sprint

---

## Tone Guidelines

**DO:**
- Use technical terminology freely
- Be directive: "Implement", "Add", "Ensure", "Validate"
- Include code examples when helpful
- Reference specific files, functions, error messages
- Explain "why" for architectural decisions

**DON'T:**
- Over-explain basic concepts to technical audience
- Use vague language ("improve", "better", "nice")
- Write long unstructured paragraphs
- Omit business context for user-facing features
- Skip acceptance criteria

---

## Actual Example (Abbreviated)

```markdown
[SD] Feature: Add Upgrade Content Configuration to Product Builder

## Overview

Enable product managers to configure upgrade content in Builder without code
changes. Currently upgrade messaging is hardcoded, requiring developer involvement
for any content updates.

## Background

**Current State**
Upgrade content exists in React components with hard-coded copy

**Problem Statement**
- PM cannot iterate on upgrade messaging without developer
- No A/B testing capability
- Slow turnaround for seasonal campaigns

## Proposed Solution

### Builder UI Component
- New "Upgrade Content" tab in Product Builder
- Rich text editor for messaging
- Image upload with preview
- Save/publish workflow

### API Layer
- New endpoints for CRUD operations on upgrade content
- Validation for required fields
- Version history tracking

## Acceptance Criteria

### Builder UI
- [ ] New tab renders in Product Builder
- [ ] Rich text editor functional with formatting options
- [ ] Image upload supports PNG/JPG up to 5MB
- [ ] Preview shows accurate rendering

### API
- [ ] POST /api/products/{id}/upgrade-content creates content
- [ ] GET /api/products/{id}/upgrade-content retrieves content
- [ ] Validation returns 400 for invalid data
- [ ] Version history maintained in database

### Testing
- [ ] Unit tests for API endpoints
- [ ] E2E test: Create product, add content, verify display
- [ ] Edge case: Missing content displays fallback gracefully

## Technical Approach

**Files to Modify:**
- `src/components/Builder/UpgradeContentTab.tsx` - New tab component
- `src/api/products.ts` - Add upgrade content endpoints
- `src/types/Product.ts` - Add UpgradeContent type
- `backend/routes/products.py` - Implement new endpoints

**Integration Points:**
- Product Builder: New tab in existing builder interface
- Content Display: Customer-facing upgrade modal
- Database: New upgrade_content table with foreign key to products

**Dependencies:**
- react-quill (already integrated) for rich text editing
- AWS S3 for image storage

## Testing Requirements

- [ ] Unit tests: API endpoints, TypeScript types
- [ ] Manual: Create product in builder, add content, verify customer-facing display
- [ ] Edge cases: Empty content, oversized images, invalid formats
```
