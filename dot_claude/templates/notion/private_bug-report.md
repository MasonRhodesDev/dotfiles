# Bug Report / Issue Documentation Template

## Use Case
Documenting bugs, issues, or problems that need to be triaged, investigated, and resolved. Ideal for QA reports, customer-reported issues, and post-incident documentation.

**Target Length:** 400–1000 words
**Tone:** Descriptive, objective, problem-focused
**Primary Audience:** Developers, QA engineers, engineering leadership

---

## Template Structure

```markdown
# [Icon] [Bug Title / Issue Name]

## Objective
[For process docs - what this process achieves]
OR
## Problem Description
[For bugs - clear statement of the issue, 1–2 sentences]

## Roles and Collaboration
[Optional - for team processes]
Define who is responsible for what aspects

## Steps / Process

1. **Step 1**: Action required
   - Sub-detail
   - Criteria or validation point

2. **Step 2**: Next action
   - Implementation detail
   - Expected outcome

## [For Bugs: Reproduction Steps]
1. Setup: Initial conditions
2. Action: What to do
3. Observe: What happens (wrong)
4. Expected: What should happen (correct)

## Status Definitions / Resolution

| Status | Description | Action |
|--------|-------------|--------|
| Status 1 | Meaning | Next steps |
| Status 2 | Meaning | Next steps |

## [Optional: Screenshots / Evidence]
[Image attachments showing the issue]

## [Optional: Archiving Policy / Related Links]
- Link to duplicate issues
- Link to root cause analysis
- Link to permanent fix
```

---

## Filling Instructions

### 1. Title
- **Format:** `[Icon] [Bug Title / Issue Name]`
- **Icons:** 🪲 for bugs, 🔴 for critical issues
- **Clarity:** Clear problem statement, not "bug" or "issue"
- **Examples:** "🪲 Patient name truncated in lab results", "🔴 API timeout during bulk patient upload"

### 2. Problem Description
- **Length:** 1–2 sentences
- **Content:** Clear statement of the issue
- **Specificity:** What's broken? Who does it affect?
- **Measurability:** Quantify impact when possible (e.g., "affects 23% of users")
- **Examples:**
  - "When creating a new patient with a name longer than 50 characters, the last name is truncated, causing duplicate patient records"
  - "API endpoint /patients returns 500 error when processing bulk import > 10,000 records"

### 3. Reproduction Steps
- **Format:** Numbered list with clear sequence
- **Details:**
  1. **Setup:** Initial conditions and prerequisites
  2. **Action:** What user/system does to trigger the bug
  3. **Observe:** What actually happens (the problem)
  4. **Expected:** What should happen
- **Precision:** Include exact clicks, data, configurations
- **Repeatability:** Steps should reliably reproduce the issue

### 4. Expected vs. Actual Behavior
- **Expected:** What should happen in correct behavior
- **Actual:** What does happen with the bug
- **Clarity:** Explicit contrast between the two

### 5. Environment Information
- **Included Details:**
  - Browser/Application version
  - Operating system
  - Database/API version
  - User account type (admin, standard, etc.)
  - Date/time of occurrence
- **Purpose:** Helps developers reproduce in matching environment

### 6. Impact & Severity
- **Severity Levels:**
  - **P1 (Critical):** System down, data loss, security breach
  - **P2 (High):** Feature broken, significant impact to users
  - **P3 (Medium):** Feature partially broken, workaround exists
  - **P4 (Low):** Minor cosmetic issue, nice-to-fix
- **Impact:** How many users affected? What's the business impact?

### 7. Screenshots / Evidence
- **Purpose:** Visual proof of the issue
- **Quality:** Clear, annotated where needed
- **Quantity:** 1–3 screenshots typically sufficient
- **Annotation:** Use arrows or callouts to highlight problem areas

### 8. Reproduction Evidence (Optional)
- **Database Queries:** SQL to reproduce data state
- **API Calls:** cURL commands that trigger the issue
- **Logs:** Error messages or stack traces
- **Configuration:** Settings that trigger the bug

### 9. Related Issues
- **Duplicates:** Link to other reports of same issue
- **Dependencies:** Related bugs that must be fixed first
- **Root Cause:** Link to analysis if known
- **Related Work:** Link to fixes or PRs addressing this

### 10. Investigation & Resolution
- **Status:** Investigating, Root Cause Found, Fixed, Verified
- **Root Cause:** Once identified, clear explanation
- **Fix:** Link to PR/commit that resolves issue
- **Verification:** Steps to verify fix (usually same as reproduction steps)

---

## Metadata / Properties to Set

**Essential Properties:**
- **Title:** Same as page title
- **Status:** New, Investigating, Root Cause Found, In Progress, Fixed, Verified, Closed
- **Severity:** P1, P2, P3, P4
- **Responsible/Assignee:** Developer assigned to fix
- **Reporter:** QA or user who reported issue

**Common Properties:**
- **Type:** Bug, Issue, Problem, Design flaw
- **Affected System:** Backend, Frontend, Mobile, API, Database
- **Created Date:** When bug was reported
- **Found In Version:** Software version where bug exists
- **Fixed In Version:** Version containing the fix

**Conditional Properties:**
- **Priority:** Urgent, High, Normal, Low (different from Severity)
- **Affected Users:** Number or percentage of users impacted
- **Internal vs. Customer:** Whether customer is aware
- **Related Issues:** Links to duplicates or dependencies
- **Root Cause Analysis:** Link to detailed analysis
- **GitHub Issue:** Link to GitHub issue/PR

---

## Tone Guidelines

### Voice
- **Objective and Descriptive:** Facts, not opinions
- **Problem-Focused:** Clear what's broken and why it matters
- **Evidence-Based:** Supported by screenshots, logs, reproduction steps

### Structure
- **Numbered Steps:** For reproduction sequences
- **Bulleted Lists:** For supporting details
- **Tables:** For status or severity definitions

### Examples
- ✅ "When creating a patient with name > 50 chars, last name is truncated, creating duplicate records"
- ✅ "API times out after 30 seconds processing 10,000+ records in bulk import"
- ✅ "Affects 12% of daily active users on mobile app"
- ❌ "The system is broken" (too vague)
- ❌ "I think there's a bug with patient names" (uncertain)
- ❌ "This is really annoying" (subjective)

---

## Visual Design Patterns

### Section Organization
- Use `##` for main sections (Problem Description, Reproduction Steps, etc.)
- Use `###` for subsections (Expected Behavior, Actual Behavior)
- Use `####` rarely (for very complex bugs)

### Callout Blocks
- **🔴 Red:** Critical severity or immediate action required
- **🟡 Yellow:** Important notes or workaround if available
- **💡 Gray:** Additional context or background information
- **✅ Green:** Verification steps or confirmation

### Evidence Organization

**Screenshots:**
- Clear, annotated images showing the problem
- Include before/after if applicable
- Use captions to explain what's shown

**Code Blocks:**
```sql
-- Query showing data state that triggers bug
SELECT * FROM patients WHERE LENGTH(last_name) > 50;
```

```bash
# cURL reproducing API timeout
curl -X POST "https://api.example.com/bulk-import" \
  -H "Authorization: Bearer token" \
  -H "Content-Type: application/json" \
  -d @10k-records.json
```

### Status Tracking
| Status | Meaning | Next Step |
|--------|---------|-----------|
| 🔵 New | Just reported | Assign to developer or triage |
| 🟡 Investigating | Dev analyzing | Find root cause |
| 🟠 Root Cause Found | Cause identified | Create fix |
| 🟢 In Progress | Fix being developed | Code review |
| ⚪ Fixed | Fix deployed | QA verification |
| ✅ Verified | QA confirms fix | Close |

---

## Quick Checklist

Before publishing:

- [ ] **Title** includes icon and clear problem statement
- [ ] **Problem Description** is 1–2 sentences, specific and measurable
- [ ] **Reproduction Steps** are numbered and detailed
  - [ ] Setup conditions are clear
  - [ ] Actions are specific (exact clicks, data, etc.)
  - [ ] Observable problem is clear
  - [ ] Expected behavior is stated
- [ ] **Environment Information** includes:
  - [ ] Software version(s)
  - [ ] Browser/OS if applicable
  - [ ] User account type
  - [ ] Date/time of occurrence
- [ ] **Impact & Severity** clearly stated
  - [ ] Severity level assigned (P1–P4)
  - [ ] Number/percentage of affected users
- [ ] **Screenshots / Evidence** provided
  - [ ] Clear and annotated
  - [ ] Shows the problem
- [ ] **Related Issues** section includes:
  - [ ] Duplicates (if any)
  - [ ] Dependencies
  - [ ] Related PRs/commits
- [ ] **No vague language:** All statements are specific and testable
- [ ] **Properties** set: Status, Severity, Assignee, Affected System

---

## Real-World Example: Critical Bug

```markdown
# 🔴 Patient name truncated in lab results (Severity: P1)

## Problem Description
When displaying lab results for patients with names longer than 50 characters, the last name is truncated to 50 characters, causing system to create duplicate patient records when name is later corrected. This affects approximately 3.2% of daily active users and has resulted in 47 duplicate records created in production this week.

---

## Environment Information
- **Affected Version:** v64.0.0, v64.0.1
- **Platform:** Web application (all browsers)
- **Database:** PostgreSQL 14.2 production
- **User Type:** All user types (admin, clinician, patients)
- **Date Reported:** Feb 1, 2026
- **Time of First Report:** ~2:30 PM UTC

---

## Reproduction Steps

1. **Setup:** Access patient portal admin dashboard with write permissions
2. **Action:** Create new patient with name: "Christopher Schwarzenegger-O'Neill"
3. **Observe:** Last name field displays "Schwarzenegger-O'Neill" (29 characters) truncated in UI as "Schwarzenegger-O'N", showing only first 50 chars of full name
4. **Expected:** Full last name should display: "Schwarzenegger-O'Neill" (29 characters total)

**Detailed Steps:**
- Login to patient portal (staging or production)
- Click "Add New Patient" button
- Fill in form:
  - First Name: "Christopher"
  - Last Name: "Schwarzenegger-O'Neill"
  - Email: "test@example.com"
  - DOB: "1990-01-01"
- Click "Create Patient"
- Navigate to patient detail page
- Observe last name field

---

## Expected vs. Actual Behavior

**Expected Behavior:**
- Full name "Christopher Schwarzenegger-O'Neill" is saved and displayed
- No duplicate records created if name is edited
- Lab results show correct, complete patient name

**Actual Behavior:**
- Last name truncated to 50 characters in database: "Schwarzenegger-O'N"
- When name is corrected to full version, system treats it as new patient
- Lab results may be tied to old truncated name record
- Search by full last name fails to find patient
- Results in duplicate patient records (confirmed: 47 instances this week)

---

## Impact & Severity

**Severity:** P1 (Critical)
- **Data Integrity:** Duplicate records break patient health record continuity
- **Affected Users:** 3.2% of daily active users (approximately 1,200 users)
- **Business Impact:** Incorrect lab results, potential patient safety issues
- **Timeline:** Urgent - production issue actively creating bad data

---

## Screenshots / Evidence

[Screenshot 1: Create Patient Form - Name Field]
Shows form with long last name being entered

[Screenshot 2: Patient List - Truncated Name]
Shows patient list with truncated "Schwarzenegger-O'N" in the name column

[Screenshot 3: Database View - Truncated Record]
SQL query output showing name column limited to 50 characters

---

## Database Evidence

**SQL Query Showing Issue:**
```sql
-- Query showing truncated names in patient table
SELECT id, first_name, last_name, LENGTH(last_name) as name_length
FROM patients
WHERE LENGTH(last_name) > 50
ORDER BY created_at DESC
LIMIT 10;

-- Results show names truncated to 50 chars
id          | first_name    | last_name              | name_length
pat_123     | Christopher   | Schwarzenegger-O'N     | 50
pat_124     | Alexander     | Vanderbilt-Weatherfie  | 50
```

**Schema Issue:**
```sql
-- Current patient table definition - PROBLEM AREA
CREATE TABLE patients (
  id VARCHAR(20) PRIMARY KEY,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(50) NOT NULL,  -- ← LIMITATION: Only 50 chars!
  email VARCHAR(255),
  date_of_birth DATE
);
```

---

## Reproduction API Call

```bash
# cURL call that creates the issue
curl -X POST "https://api.example.com/v2/patients" \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "firstName": "Christopher",
    "lastName": "Schwarzenegger-O'"'"'Neill",
    "email": "chris@example.com",
    "dateOfBirth": "1990-01-01"
  }'

# Response shows name truncated in stored value
{
  "id": "pat_123",
  "firstName": "Christopher",
  "lastName": "Schwarzenegger-O'N",  ← Truncated!
  "email": "chris@example.com",
  "createdAt": "2026-02-01T14:30:00Z"
}
```

---

## Status & Investigation

**Current Status:** Root Cause Found

**Root Cause:**
The `patients` table's `last_name` column has VARCHAR(50) constraint, truncating names longer than 50 characters. Migration script from v63 to v64 didn't increase column size to VARCHAR(255).

**Affected Database Schema:**
- Table: `patients`
- Column: `last_name`
- Current: `VARCHAR(50)`
- Required: `VARCHAR(255)`

**Related Code:**
- [Schema definition: db/schema.sql](https://github.com/example/repo/blob/main/db/schema.sql#L15)
- [Migration script: db/migrations/v64_patient_schema.sql](https://github.com/example/repo/blob/main/db/migrations/v64_patient_schema.sql)
- [Patient model: src/models/Patient.ts](https://github.com/example/repo/blob/main/src/models/Patient.ts#L45)

---

## Related Issues & Duplicates

- Duplicate Report: [🪲 Long patient names not stored correctly](link-to-duplicate) - Same issue, reported via customer support
- Related Issue: [First name truncation issue - already fixed in v63](link-to-related)
- Blocking: [Data cleanup needed for 47 duplicate records](link-to-cleanup-task)

---

## Workaround (Temporary)
Until fix is deployed:
- Abbreviate last names to 50 characters or fewer during patient creation
- Manually merge duplicate records in admin panel (contact DevOps)
- Use first + last name search instead of last name only

---

## Next Steps

1. **Developer:** Create migration to expand `last_name` column to VARCHAR(255)
2. **Developer:** Update Patient model validation to accept up to 255 chars
3. **Testing:** Create E2E test ensuring names > 50 chars are stored/retrieved correctly
4. **QA:** Verify with provided reproduction steps
5. **DevOps:** Deploy fix to staging, validate, then production
6. **Admin:** Run deduplication script to merge 47 duplicate records
7. **Customer Support:** Notify affected users of issue + fix
```

---

## Bug Report Best Practices

### Reproduction Quality
- Be as specific as possible (exact data, exact steps, exact expected result)
- Use real data when possible (first and last names that trigger the issue)
- Include all prerequisite setup steps
- Test reproduction steps yourself before filing report

### Evidence Collection
- Screenshots showing the problem
- Error messages from browser console or server logs
- Database queries showing affected data
- API calls that trigger the issue
- Links to GitHub code if you've identified the problem area

### Clarity & Precision
- Use exact field names, exact values, exact URLs
- Distinguish between "nice-to-fix" and "must-fix" issues
- Quantify impact (% of users, count of affected records)
- Link to related issues to show pattern

### Follow-Up
- Update status and root cause findings as investigation proceeds
- Link to PR/commit once fix is deployed
- Document verification steps to confirm fix works
- Close issue only after QA verification

---

## Example: Minor Bug (P4)

```markdown
# 🪲 Dashboard loading indicator spins incorrectly

## Problem Description
When loading dashboard with > 1000 notifications, the loading spinner rotates counter-clockwise (backwards) instead of clockwise, creating visual confusion.

---

## Reproduction Steps
1. Create user account with 1500+ notifications
2. Navigate to dashboard
3. Observe: Loading spinner rotates counter-clockwise
4. Expected: Spinner should rotate clockwise

---

## Severity: P4 (Low)
- Cosmetic issue only
- Does not affect functionality
- No user data impact
- Workaround: Dashboard loads correctly, just visual quirk

---

## Screenshots
[Screenshot showing counter-clockwise spinner]

---

## Suspected Cause
CSS animation direction property set incorrectly in `dashboard.css` line 245
```

---

**Template Version:** 1.0
**Last Updated:** February 3, 2026
**Based on:** Notion Page Analysis & Template Guide
