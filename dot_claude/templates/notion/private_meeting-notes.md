# Meeting Notes Template

## Use Case
Capturing meeting discussions, decisions, and action items in a concise, actionable format. Ideal for team syncs, planning sessions, retrospectives, and stakeholder meetings.

**Target Length:** 300–800 words
**Tone:** Concise, action-oriented, collaborative
**Primary Audience:** Team members, stakeholders, decision-makers

---

## Template Structure

```markdown
# [Meeting Name] - [Date Optional]

## **1. Overview**
Short description of the meeting purpose.

## **2. Key Topics & Decisions**
- **Topic 1**: Brief discussion summary
  - Decision made
  - Rationale if important
- **Topic 2**: Discussion point
  - Clarification or agreement reached

## **3. Action Items**
- **@Owner:** Specific action with clear deliverable
- **@Owner:** Another action with timeline if applicable
- **@Owner:** Third action

## **4. Implementation Notes**
[Optional section for technical meetings]
Technical details, configurations, commands, file paths, or instructions discussed.

\`\`\`bash
# Example commands or configurations discussed
\`\`\`

## **5. Newly Identified Process**
[Optional - for process changes]
- Brief description of any new or updated workflow/process mentioned.

**Potential Conflicts / Clarifications Needed:**
- Items requiring further discussion or confirmation

## **6. Clarifications / Follow-Ups**
- Open questions that need answering
- Items to revisit in next meeting
```

---

## Filling Instructions

### 1. Title
- **Format:** `[Meeting Name] - [Date]`
- **Clarity:** Use meeting purpose as title when not recurring
- **Examples:** "Cloud-Infra Team Meeting Notes", "Q1 Planning Session - Feb 3, 2026"

### 2. Overview
- **Length:** 1–2 sentences max
- **Content:** Purpose of meeting, attendees, key context
- **Examples:**
  - "Weekly sync to align on infrastructure priorities and ongoing incidents"
  - "Sprint planning for Q1 2026, 5 participants from backend and QA teams"

### 3. Key Topics & Decisions
- **Format:** Bulleted list with main topic bolded
- **Organization:** Topic → Decision(s) and Rationale
- **Brevity:** 1–3 sentences per topic
- **Emphasis:** Put decisions in bullet points under topics

### 4. Action Items
- **Format:** `**@Owner:** Specific action with clear deliverable`
- **Ownership:** Every action must have explicit owner with @ mention
- **Timeline:** Include deadline when applicable (e.g., "by EOW", "by Tuesday")
- **Clarity:** What is being done, by whom, and when

### 5. Implementation Notes (Optional)
- **Use When:** Technical meeting discussing configurations, commands, or setup steps
- **Format:** Code blocks with language highlighting
- **Organization:** Group by topic or system

### 6. Newly Identified Process (Optional)
- **Use When:** Meeting changes workflows or introduces new procedures
- **Format:** Bullet list describing new process
- **Clarifications:** Include "Potential Conflicts" sub-section if ambiguity exists

### 7. Clarifications / Follow-Ups
- **Purpose:** Capture unanswered questions and topics for next meeting
- **Format:** Bulleted list of open items
- **Clarity:** Each item must be actionable or have clear follow-up owner

---

## Metadata / Properties to Set

**Essential Properties:**
- **Title:** Same as page title
- **Type:** Meeting Notes (or specific meeting type)
- **Date:** Meeting date (often auto-populated from title)

**Common Properties:**
- **Meeting Type:** Weekly Sync, Planning, Retrospective, One-on-One
- **Attendees:** People property listing participants
- **Next Meeting:** Date of follow-up meeting

**Conditional Properties:**
- **Decisions Documented:** Checkbox if significant decisions were made
- **Action Items Count:** Formula or manual count of tasks assigned
- **Owner/Facilitation:** Person who led the meeting

---

## Tone Guidelines

### Voice
- **Concise:** Fragment sentences acceptable for brevity (e.g., "API gateway timeout alerts missing")
- **Action-Oriented:** Focus on decisions and next steps, not narrative
- **Collaborative:** Acknowledge contributions and alignment ("Team agreed to...")

### Structure
- **Bullets for Lists:** Easier scanning
- **Numbers for Sequences:** Only if order matters
- **Numbering for Sections:** Standard structure for easy reference

### Examples
- ✅ "@John: Follow up with client by EOW"
- ✅ "Decision: Use `programCode` instead of deprecated `program` param"
- ✅ "Database migration timeline: Q2 2026, with 2-week parallel run"
- ❌ "John might follow up with the client sometime soon" (vague)
- ❌ "We discussed the database thing" (no decision)

---

## Visual Design Patterns

### Section Headers
- Use `##` with bold numbering: `## **1. Overview**`
- Provides clear visual hierarchy
- Eases reference in follow-up messages ("See section 3 for your action item")

### Callout Blocks (Optional)
- **💡 Gray:** Background context or tips
- **🟡 Yellow:** Important decisions needing attention
- **🔴 Red:** Blockers or urgent items
- **✅ Green:** Confirmed decisions or successes

### @ Mentions
- Use Notion @mentions to tag owners
- Creates accountability and notifications
- Example: `**@DevOpsLead:** Create migration runbook by end of week`

### Code Blocks
When including technical details:

```yaml
# Monitoring configuration discussed
alert: api_gateway_timeout
threshold: 5s
window: 5m
action: page_oncall
```

---

## Quick Checklist

Before publishing:

- [ ] **Title** includes meeting name and date
- [ ] **Overview** section is 1–2 sentences describing purpose
- [ ] **Key Topics & Decisions** section includes:
  - [ ] All major topics discussed
  - [ ] Explicit decisions made
  - [ ] Rationale when important
- [ ] **Action Items** section includes:
  - [ ] All tasks assigned
  - [ ] Owner mentioned with @ for each item
  - [ ] Clear deliverables stated
  - [ ] Deadlines included where applicable
- [ ] **Implementation Notes** (if applicable) has code blocks and clear organization
- [ ] **Newly Identified Process** (if applicable) describes workflow changes
- [ ] **Follow-Ups** section captures unanswered questions
- [ ] **No vague language:** All decisions and actions are specific
- [ ] **Properties** are set: Meeting Type, Attendees, Date

---

## Real-World Example

```markdown
# Cloud-Infra Team Meeting Notes - Feb 3, 2026

## **1. Overview**
Weekly sync to align on infrastructure priorities and ongoing incidents. 5 attendees: DevOps lead, 2 SREs, Infrastructure engineer, and Team lead.

## **2. Key Topics & Decisions**

- **Database migration timeline**: Agreed to move main migration to Q2 2026
  - Parallel systems will run for 2 weeks before cutover
  - Rationale: Gives us time to validate data consistency before full switch

- **Monitoring gaps**: Identified missing alerts for API gateway timeouts
  - Decision: Add new alerting rules by next Tuesday
  - Threshold: 5 seconds for 5-minute window

- **Backup restoration testing**: Need to validate SLA compliance
  - Decision: Run quarterly disaster recovery drill starting next month
  - Team to document findings in runbook

## **3. Action Items**

- **@DevOpsLead:** Create migration runbook by EOW (Feb 7)
  - Include: pre-migration checklist, cutover steps, rollback procedure
  - Share with team for review by Feb 6

- **@SREEngineer:** Set up API gateway timeout alerts by Tuesday (Feb 4)
  - Threshold: 5s, window: 5m
  - Test in staging first before prod deployment

- **@TeamLead:** Schedule quarterly disaster recovery drill for mid-March
  - Coordinate with all infrastructure and ops teams
  - Send calendar invite by EOW

- **@BackupSpecialist:** Document backup restoration SLA in runbook
  - Current target: 1-hour RTO, 15-minute RPO
  - Validate against production testing results

## **4. Implementation Notes**

New monitoring config to be deployed:

\`\`\`yaml
# Prometheus alert rules
- alert: APIGatewayHighLatency
  expr: histogram_quantile(0.99, request_duration_seconds) > 5
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "API gateway latency high ({{ $value }}s)"
\`\`\`

Database migration connection string format:
\`\`\`
postgres://user:pass@new-db-prod:5432/main_db?sslmode=require
\`\`\`

## **5. Newly Identified Process**

Added weekly monitoring review meeting:
- Every Tuesday at 3pm UTC
- Review alert firing patterns from previous week
- Discuss tuning threshold or alert rules
- Duration: 30 minutes

**Potential Conflicts:**
- Overlaps with existing architecture sync; need to find alternative time slot

## **6. Clarifications / Follow-Ups**

- Need client approval on acceptable downtime window for migration (2–4 hours)
- Confirm backup restoration time is acceptable per SLA
- Clarify whether parallel database setup needs to run 2 weeks or can be shorter
- Review disaster recovery drill scope with security team

**Follow-up owner:** @TeamLead to collect client feedback by Feb 5
**Next meeting:** Feb 10, 2026 at 2pm UTC
```

---

## Meeting Notes Best Practices

### Capture Discipline
- Record decisions immediately, not from memory
- Use shorthand during meeting, expand during write-up
- Assign action items in real-time to ensure clarity

### Ownership & Accountability
- Every action item must have explicit owner
- Use @ mentions so people are notified
- Include deadline for each item
- Follow up on previous meeting's action items at start of next meeting

### Clarity & Precision
- Avoid "we should discuss this later"—assign to owner and date
- When unclear, assign clarification task to specific person
- Link to related documentation when possible

### Timing
- Publish notes same day if possible
- Include date for context in future reference
- Link notes to calendar event or shared project

---

**Template Version:** 1.0
**Last Updated:** February 3, 2026
**Based on:** Notion Page Analysis & Template Guide
