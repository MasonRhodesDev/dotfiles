# Ticket Creation Templates

Tone-appropriate templates for creating ClickUp tickets and Notion pages based on real organizational patterns and your communication style.

## Quick Start

1. **Choose your platform:** ClickUp or Notion
2. **Identify ticket type:** Use decision tree in `ticket-creation-guide.md`
3. **Select template:** Browse `clickup/` or `notion/` directories
4. **Fill and customize:** Follow template instructions
5. **Create ticket:** Use MCP tools or copy to platform

## Directory Structure

```
templates/
├── README.md                       # This file
├── ticket-creation-guide.md        # Master reference guide
├── clickup/                        # ClickUp templates
│   ├── complex-feature.md          # Dev work 2,000-8,000 chars
│   ├── bug-fix.md                  # Bug reports 50-300 chars
│   ├── feature-request.md          # Features 300-1,000 chars
│   ├── marketing-creative.md       # Marketing 200-800 chars
│   └── qa-validation.md            # QA tasks 400-1,500 chars
└── notion/                         # Notion templates
    ├── technical-task.md           # Tasks 800-1,200 words
    ├── process-doc.md              # Processes 1,500-3,000 words
    ├── meeting-notes.md            # Meetings 300-800 words
    ├── reference-doc.md            # Reference docs (varies)
    └── bug-report.md               # Bug reports 400-1,000 words
```

## Using the Templates

### With Claude Code

**Recommended:** Let Claude guide you:
```
"Create a ClickUp ticket for fixing the login bug"
"Create a Notion page for documenting the API"
```

Claude will:
- Ask clarifying questions
- Select appropriate template
- Fill sections based on your input
- Calibrate tone for context

### With Helper Scripts

**Template Selection:**
```bash
~/.claude/skills/create-ticket/select-template.sh
```
Interactive prompt to choose the right template.

**Ticket Generation:**
```bash
~/.claude/skills/create-ticket/generate-ticket.sh clickup/bug-fix.md \
  --title="Fix login bug" \
  --issue="Users can't login" \
  --fix="Reset session"
```

**Tone Calibration:**
```bash
~/.claude/skills/create-ticket/tone-calibrate.sh \
  "Please review this pull request" 2
# Output: "review?"
```

### Manual Usage

1. Browse template files in `clickup/` or `notion/`
2. Copy template section from chosen file
3. Fill in placeholders: `[like this]` or `{like this}`
4. Follow "Filling Instructions" section in template
5. Verify with "Quick Checklist" at bottom

## Decision Tree

```
What are you creating?

ClickUp Ticket?
├─ Complex dev feature → clickup/complex-feature.md
├─ Simple bug fix → clickup/bug-fix.md
├─ Feature request → clickup/feature-request.md
├─ Marketing work → clickup/marketing-creative.md
└─ QA/testing → clickup/qa-validation.md

Notion Page?
├─ Technical task → notion/technical-task.md
├─ Process/guidelines → notion/process-doc.md
├─ Meeting notes → notion/meeting-notes.md
├─ Reference doc → notion/reference-doc.md
└─ Bug/issue → notion/bug-report.md
```

## Tone Calibration

Templates default to **organizational norms** (formal, comprehensive). You can adjust tone:

| Context | Use Formal | Use Casual |
|---------|-----------|-----------|
| Dev tickets for team | ✅ Default | Internal updates only |
| Bug fixes | Default for tracking | ✅ Your style matches |
| Code reviews | Formal PR descriptions | ✅ Slack: "review?" |
| Status updates | Project reports | ✅ Quick: "done", "fixed" |
| External/client | ✅ Always formal | Never |

**Example conversions:**
- Formal: "Please review this pull request" → Casual: "review?"
- Formal: "I will investigate this issue" → Casual: "looking into it"
- Formal: "Let me know if you have questions" → Casual: "lmk if issues"

## Common Use Cases

### Bug Fix (ClickUp)
**Template:** `clickup/bug-fix.md`
**Length:** 50-300 chars
**Time:** < 2 min

Quick, terse bug reports with problem/solution format.

### Feature Spec (ClickUp)
**Template:** `clickup/complex-feature.md`
**Length:** 2,000-8,000 chars
**Time:** 10-15 min

Comprehensive development tickets with acceptance criteria, technical approach, testing requirements.

### Technical Task (Notion)
**Template:** `notion/technical-task.md`
**Length:** 800-1,200 words
**Time:** 5-10 min

Implementation tasks with Definition of Done, testing instructions, QA validation.

### Meeting Notes (Notion)
**Template:** `notion/meeting-notes.md`
**Length:** 300-800 words
**Time:** During/after meeting

Structured meeting capture with decisions, action items, follow-ups.

## Template Components

Each template includes:

✅ **Use Case** - When to use this template
✅ **Target Length** - Expected character/word count
✅ **Tone Guidelines** - Voice and style
✅ **Full Template** - Ready-to-use structure
✅ **Filling Instructions** - Step-by-step guide
✅ **Real Examples** - Actual tickets from analysis
✅ **Metadata Guide** - Properties, tags, priorities
✅ **Quick Checklist** - Pre-submission verification

## Best Practices

### DO:
- ✅ Front-load important information
- ✅ Use headers and bullets for structure
- ✅ Be specific with files, functions, errors
- ✅ Explain "why" for significant changes
- ✅ Link related work (epic, PRs, docs)
- ✅ Match length to complexity
- ✅ Assign ownership clearly
- ✅ Include acceptance criteria for features

### DON'T:
- ❌ Write vague descriptions ("make it better")
- ❌ Create wall-of-text paragraphs
- ❌ Over-explain simple concepts
- ❌ Skip business context
- ❌ Leave actions unassigned
- ❌ Use ambiguous criteria ("works well")

## Reference Documents

**Complete Guide:**
`ticket-creation-guide.md` - Master reference with:
- Decision trees
- Tone calibration matrix
- Section library (reusable blocks)
- Anti-patterns guide
- Platform-specific guidelines
- Examples: before & after

**Analysis Basis:**
- ClickUp: 15+ tickets analyzed
- Notion: 15+ pages analyzed
- Your tone: 50+ Slack messages analyzed

**Full Analysis Documents:**
- ClickUp patterns: `~/.claude/plans/goofy-gathering-sedgewick-agent-af9521f.md`
- Notion patterns: `/home/mason/notion-page-analysis-template.md`
- Your tone map: `~/.claude/plans/goofy-gathering-sedgewick-agent-a29c5ed.md`

## Integration with MCP

After generating ticket description:

**ClickUp:**
```python
clickup_create_task(
    list_id="your_list_id",
    name="Ticket title",
    markdown_description="<generated description>",
    # ... other fields
)
```

**Notion:**
```python
notion_create_pages(
    parent={"page_id": "parent_id"},
    pages=[{
        "properties": {"title": "Page title"},
        "content": "<generated markdown>"
    }]
)
```

## Examples Gallery

### Example 1: ClickUp Bug Fix

**Input:** "Login fails for returning users"

**Output (using bug-fix template):**
```
[AP] Fix bug with returning user login

Reported By: Customer Support

Issue:
Returning users unable to login - session validation failing on token refresh

Fix:
Update token refresh logic to handle expired refresh tokens gracefully
```

### Example 2: Notion Technical Task

**Input:** "Add Google OAuth to authentication system"

**Output (using technical-task template):**
```markdown
# 🪨 Add Google OAuth Authentication

### Task description
Implement Google OAuth 2.0 sign-in flow per [Epic: SSO Auth]. Allow users to
sign in with Google account or link existing account.

---

### Technical Definition of done
- [ ] Google OAuth flow implemented
  - [ ] OAuth client configured in Google Cloud Console
  - [ ] Callback endpoint handles auth code exchange
  - [ ] User session created with Google profile data
- [ ] Account linking for existing users
- [ ] Error handling for declined permissions
- [ ] Tests written for auth flow

---

## How to test
- [ ] New user: Sign in with Google → account created
- [ ] Existing user: Link Google account → login works
- [ ] Declined permissions → error message shown
- [ ] Token refresh → session maintained
```

## Troubleshooting

**Template not found?**
- Check path: `/home/mason/.claude/templates/clickup/` or `.../notion/`
- Verify filename ends with `.md`

**Generated ticket too verbose?**
- Check target length in template header
- Remove optional sections
- Use bullet points over paragraphs

**Tone feels wrong?**
- Check tone guidelines in template
- Use `tone-calibrate.sh` to adjust
- Specify "Make this more casual/formal" to Claude

**Missing sections?**
- Refer to "Common Sections" in master guide
- Check template's "Filling Instructions"
- Some sections are optional - remove if not applicable

## Maintenance

**When to Update:**
- Organizational patterns change
- New ticket types emerge
- Team feedback on templates
- Platform features change

**How to Update:**
1. Review recent tickets for pattern shifts
2. Edit template files in this directory
3. Update `ticket-creation-guide.md`
4. Update this README if structure changes

## Version History

**v1.0** (2026-02-03)
- Initial release
- 10 templates (5 ClickUp + 5 Notion)
- Based on 30+ tickets/pages analyzed
- Your tone map from 50+ Slack messages
- 3 helper scripts included

## Getting Help

1. **Read the master guide:** `ticket-creation-guide.md`
2. **Check examples:** Each template has real-world examples
3. **Ask Claude:** "Help me create a [type] ticket in [platform]"
4. **Review analysis docs:** See patterns from real tickets

## Related

- **Skill:** `~/.claude/skills/create-ticket/`
- **Helper Scripts:** `~/.claude/skills/create-ticket/*.sh`
- **Global Instructions:** `~/.claude/CLAUDE.md` (references this system)
