# ClickUp Template: Bug Fix

**Use for:** Clear, scoped bugs with straightforward fixes
**Target length:** 50-300 characters
**Tone:** Terse, factual, direct

---

## Template

```markdown
[Component] Fix bug with [specific issue]

Reported By:
[Person or system that identified the bug]

Issue:
[1-2 sentences describing the problem and when it occurs]

Fix:
[1-2 sentences describing the solution]
```

---

## Filling Instructions

**Title:**
- Include component prefix in brackets: `[AP]`, `[SD]`, `[Builder]`
- Use "Fix bug with..." format
- Be specific about what's broken

**Reported By:**
- Name the person who found it, or "QA Team", "Customer Support", etc.
- Can be a system: "Error monitoring", "Sentry", "Logs"

**Issue:**
- Describe what's wrong in 1-2 sentences
- State when/how it occurs if not obvious
- Past tense: "Introduced a bug...", "Started failing..."

**Fix:**
- Describe solution in 1-2 sentences
- Imperative tone: "Remove...", "Update...", "Change..."
- Be specific about the change

---

## Actual Examples

### Example 1: Minimal

```markdown
[AP] Fix bug with Manage Prospects offer change

Reported By:
QA Team

Issue:
Introduced a bug with the feature for new Product Configs loading a different offer.

Fix:
Remove on change trigger so that the offer is not updated.
```

### Example 2: With Specific Context

```markdown
[SD] Vouched logic writing invalid logs

Reported By:
DevOps - Splunk alerts

Issue:
Vouched integration logging malformed JSON, breaking log aggregation pipeline.

Fix:
Update logger to stringify nested objects before writing to stdout.
```

### Example 3: With Reference

```markdown
[Builder] Graph validation false positive on condition nodes

Reported By:
Product team via Slack

Issue:
Validation incorrectly flags valid condition nodes as "unterminated" when they have fallback paths.

Fix:
Update DFS traversal to check fallback edges before marking node as error.
```

---

## Metadata to Set

**Tags:** Component tag (1-2 max)
**Priority:**
- Urgent if hotfix/blocking
- High if significant impact
- Normal for standard bugs
- Low for minor issues
**Story Points:** Usually 1-2 for bugs
**List:** Bug list or current sprint
**Assignee:** Yourself or assigned developer

---

## Tone Guidelines

**DO:**
- Be terse - every word counts
- Use past tense for problem: "Introduced", "Started failing", "Broke"
- Use imperative for fix: "Remove", "Update", "Fix"
- State facts without emotion
- Focus on what and how, not why

**DON'T:**
- Write long explanations
- Include unnecessary background
- Add speculative commentary
- Over-apologize or dramatize
- Include implementation details unless critical

---

## Length Guidelines

**Total character count:** 50-300 characters is the sweet spot

**If under 50 chars:** Too minimal - add context
**If 100-200 chars:** Perfect for simple bugs
**If 200-300 chars:** Good for bugs needing context
**If over 300 chars:** Consider if this is actually a bug or a feature change

---

## When NOT to Use This Template

Use a different template if:
- Fix requires multiple files/components → Use complex-feature template
- Bug is really a feature request → Use feature-request template
- Requires investigation/analysis → Create investigation task first
- Involves process changes → Use process documentation

---

## Quick Checklist

Before submitting:
- [ ] Title includes component prefix
- [ ] Reported by is clear
- [ ] Issue is 1-2 sentences, states the problem
- [ ] Fix is 1-2 sentences, states the solution
- [ ] Total length < 300 chars
- [ ] Tags set appropriately
- [ ] Priority reflects urgency
