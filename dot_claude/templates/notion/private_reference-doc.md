# Reference Documentation Template

## Use Case
Technical reference materials for APIs, databases, architecture, credentials, and system documentation. Ideal for developers and DevOps teams needing precise, quickly-scannable information.

**Target Length:** 500–2000 words (varies by complexity)
**Tone:** Technical, precise, reference-style
**Primary Audience:** Developers, DevOps engineers, technical teams

---

## Template Structure

```markdown
# [Icon] [Documentation Title]

[Table of Contents - for longer docs]

# [Main Topic]

## Description
Brief overview of what this documents and its purpose.

## [Category 1 - e.g., Credentials, Collections]
### General
- Link to overview documentation

### [Specific Item]
- **Parameter/Field**: Description and type
- **Usage**: When and how to use
- **Example**: Code snippet or URL

\`\`\`language
# Code example if applicable
example_code_here
\`\`\`

## [Category 2]
### [Sub-category]
[Structured information with links]

- [External link](URL) - Description
- [Internal link](notion page) - Description

## Related Documentation
- Link to related page 1
- Link to related page 2
```

---

## Filling Instructions

### 1. Title
- **Format:** `[Icon] [Documentation Title]`
- **Icons:** 💽 for database/technical, 🔑 for credentials/secrets, 🏗️ for architecture
- **Examples:** "💽 Patient API Reference", "🔑 Database Credentials", "🏗️ System Architecture"

### 2. Table of Contents (Optional)
- **Use When:** Documentation exceeds 1500 words
- **Format:** Bulleted list of main sections with links
- **Purpose:** Quick navigation for long documents
- **Example:**
  ```markdown
  - [Description](#description)
  - [Endpoints](#endpoints)
  - [Authentication](#authentication)
  - [Examples](#examples)
  ```

### 3. Description
- **Length:** 2–4 sentences
- **Content:** Purpose, scope, use cases
- **Clarity:** What this document covers and doesn't cover
- **Example:** "This document describes all REST endpoints for the Patient Portal API, including authentication, request/response formats, and usage examples. Architecture decisions are documented in [System Architecture Overview]."

### 4. Category Sections
- **Headings:** Use `##` for major categories, `###` for subcategories
- **Organization:** Group related items logically
- **Structure:** General overview → Specific items

### 5. Specific Item Details
- **Format:** Bold labels with descriptions
- **Content:**
  - `**Field/Parameter**: Description with type`
  - `**Usage**: When and how to use`
  - `**Example**: Code or URL snippet`
- **Precision:** Use exact names, types, and formats

### 6. Code Examples
- **Language:** Use syntax highlighting appropriate to content
- **Context:** Include comments explaining purpose
- **Conciseness:** Show minimal viable example
- **Formats:** Support JSON, YAML, SQL, HTTP, etc.

### 7. External References
- **Purpose:** Link to Swagger, GitHub, external docs
- **Format:** `[Link text](URL) - Brief description`
- **Organization:** Group by type (Swagger, GitHub, etc.)

### 8. Related Documentation
- **Placement:** End of document
- **Format:** Bulleted list of related pages
- **Purpose:** Help readers discover related information
- **Examples:** Architecture, API specs, setup guides

---

## Metadata / Properties to Set

**Essential Properties:**
- **Title:** Same as page title
- **Type:** Technical Reference, API Documentation, Database Documentation, Architecture
- **Owner:** Primary author/maintainer

**Common Properties:**
- **Status:** Current, Deprecated, In Progress, Archived
- **Created/Last Edited Time:** Automatic metadata
- **Project:** Associated project or system

**Conditional Properties:**
- **Version:** API version (e.g., v2, v3)
- **Last Updated:** Manual date if different from system metadata
- **Access Level:** Public, Team, Internal, Restricted
- **Related Documentation:** Links to dependent docs

---

## Tone Guidelines

### Voice
- **Neutral and Descriptive:** Objective, non-prescriptive
- **Precision:** Exact parameter names, types, formats
- **Brevity:** Maximum information density, minimal prose

### Structure
- **Numbered Parameters:** For API endpoints
- **Bulleted Lists:** For attributes or options
- **Tables:** For comparisons or complex structures

### Examples
- ✅ "`programCode`: String - Program code or ID for the program"
- ✅ "`dueDate`: ISO 8601 format (YYYY-MM-DD) or null if not set"
- ✅ "Username: user | Password: sjxN5ywWPAUJP2 | Database: production"
- ❌ "The program code, which is basically the ID" (imprecise)
- ❌ "Maybe try using the API endpoint?" (vague)

---

## Visual Design Patterns

### Section Hierarchy
```markdown
# Document Title (rarely repeated in content)

## Major Category
Overview or general information

### Subcategory
Detailed information about specific items

#### Rare Fourth Level
(only for very complex documentation)
```

### Information Density Tables

**Use for API Endpoints:**
```markdown
| Method | Endpoint | Purpose | Auth Required |
|--------|----------|---------|---------------|
| GET | /api/users | List all users | Yes |
| POST | /api/users | Create user | Yes |
| GET | /api/users/{id} | Get single user | No |
```

**Use for Parameters:**
```markdown
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| program_id | String | Yes | ID of the program |
| start_date | ISO 8601 | No | Start date for filtering |
| limit | Integer | No | Max results (default: 25) |
```

### Code Blocks with Context

```javascript
// Example: Creating a resource
const response = await fetch('/api/patients', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ' + accessToken
  },
  body: JSON.stringify({
    firstName: 'John',
    lastName: 'Doe',
    email: 'john@example.com'
  })
});
```

### Callout Blocks
- **💡 Gray:** General information or tips
- **🟡 Yellow:** Important notes or prerequisites
- **⚠️ Orange:** Warnings about deprecated fields or breaking changes
- **🔴 Red:** Critical security or stability information
- **✅ Green:** Success criteria or best practices

### Color-Coded Fields
- Use `<span color="gray">` for optional fields
- Use `<span color="blue">` for required fields
- Use `<span color="red_bg">` for deprecated fields

---

## Quick Checklist

Before publishing:

- [ ] **Title** includes icon and clear topic
- [ ] **Description** clearly states what document covers
- [ ] **Table of Contents** present for docs > 1500 words
- [ ] **Categories** logically organized
- [ ] **Specific items** include:
  - [ ] Exact names and types
  - [ ] Descriptions and usage
  - [ ] Code examples where applicable
- [ ] **Code blocks** are syntactically correct
  - [ ] Include context comments
  - [ ] Use appropriate language highlighting
- [ ] **Tables** have clear headers and consistent formatting
- [ ] **External links** are current and relevant
  - [ ] Swagger/API docs linked
  - [ ] GitHub repos linked
- [ ] **Related Documentation** section includes relevant pages
- [ ] **No ambiguity:** All parameter names, types, formats are exact
- [ ] **Properties** set: Owner, Type, Status, Version (if applicable)

---

## Real-World Example

```markdown
# 💽 Patient Portal API Reference

## Description
This document describes all REST endpoints for the Patient Portal API (v2), including authentication requirements, request/response formats, status codes, and usage examples. For system architecture and design decisions, see [API Architecture Overview]. For setup and deployment, see [Patient Portal Deployment Guide].

## Table of Contents
- [Authentication](#authentication)
- [Patients Endpoints](#patients-endpoints)
- [Labs Endpoints](#labs-endpoints)
- [Medications Endpoints](#medications-endpoints)
- [Status Codes](#status-codes)
- [Rate Limiting](#rate-limiting)

## Authentication

### General
All API requests require bearer token authentication via OAuth 2.0.

- See [OAuth Setup Guide](link) for token generation
- Tokens expire after 24 hours
- Include token in `Authorization` header: `Authorization: Bearer <token>`

### Getting Access Token

**Endpoint:** `POST /oauth/token`

- **client_id**: String - Your application client ID
- **client_secret**: String - Your application secret (never expose)
- **grant_type**: String - Use `client_credentials`

```bash
curl -X POST https://api.patient.com/oauth/token \
  -H "Content-Type: application/json" \
  -d '{
    "client_id": "your_client_id",
    "client_secret": "your_client_secret",
    "grant_type": "client_credentials"
  }'
```

**Response:**
```json
{
  "access_token": "eyJhbGc...",
  "token_type": "Bearer",
  "expires_in": 86400
}
```

## Patients Endpoints

### General
- See [Patient Data Model](link) for complete field reference
- All timestamps are ISO 8601 format (YYYY-MM-DDTHH:MM:SSZ)

### List Patients

**GET** `/api/v2/patients`

**Query Parameters:**
- **page**: Integer (optional) - Page number, default: 1
- **limit**: Integer (optional) - Results per page, default: 25, max: 100
- **status**: String (optional) - Filter by status (active, inactive, pending)
- **created_after**: ISO 8601 (optional) - Filter by creation date

**Example Request:**
```bash
curl -X GET "https://api.patient.com/api/v2/patients?page=1&limit=50" \
  -H "Authorization: Bearer eyJhbGc..."
```

**Example Response:**
```json
{
  "data": [
    {
      "id": "pat_12345",
      "firstName": "John",
      "lastName": "Doe",
      "email": "john@example.com",
      "dateOfBirth": "1990-05-15",
      "status": "active",
      "createdAt": "2025-01-15T10:30:00Z"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 50,
    "total": 150,
    "totalPages": 3
  }
}
```

### Get Single Patient

**GET** `/api/v2/patients/{patientId}`

**Path Parameters:**
- **patientId**: String - Patient ID (format: pat_xxxxx)

**Example Request:**
```bash
curl -X GET "https://api.patient.com/api/v2/patients/pat_12345" \
  -H "Authorization: Bearer eyJhbGc..."
```

**Example Response:**
```json
{
  "id": "pat_12345",
  "firstName": "John",
  "lastName": "Doe",
  "email": "john@example.com",
  "phone": "+1-555-0123",
  "dateOfBirth": "1990-05-15",
  "status": "active",
  "medicalHistory": [
    {
      "condition": "hypertension",
      "diagnosedAt": "2020-03-10"
    }
  ],
  "createdAt": "2025-01-15T10:30:00Z",
  "updatedAt": "2026-02-03T14:22:00Z"
}
```

### Create Patient

**POST** `/api/v2/patients`

**Request Body:**
```json
{
  "firstName": "Jane",
  "lastName": "Smith",
  "email": "jane@example.com",
  "phone": "+1-555-0456",
  "dateOfBirth": "1985-08-22"
}
```

**Example Response (201 Created):**
```json
{
  "id": "pat_67890",
  "firstName": "Jane",
  "lastName": "Smith",
  "email": "jane@example.com",
  "status": "active",
  "createdAt": "2026-02-03T15:00:00Z"
}
```

## Labs Endpoints

### List Patient Labs

**GET** `/api/v2/patients/{patientId}/labs`

**Example Request:**
```bash
curl -X GET "https://api.patient.com/api/v2/patients/pat_12345/labs" \
  -H "Authorization: Bearer eyJhbGc..."
```

**Example Response:**
```json
{
  "data": [
    {
      "id": "lab_11111",
      "testName": "Complete Blood Count",
      "status": "completed",
      "collectedAt": "2026-01-20T09:00:00Z",
      "resultsAvailableAt": "2026-01-22T14:30:00Z"
    }
  ]
}
```

## Status Codes

| Code | Meaning | Typical Cause |
|------|---------|---------------|
| 200 | OK | Request successful |
| 201 | Created | Resource successfully created |
| 400 | Bad Request | Invalid parameters or malformed JSON |
| 401 | Unauthorized | Invalid or missing authentication token |
| 403 | Forbidden | Token valid but insufficient permissions |
| 404 | Not Found | Resource does not exist |
| 429 | Too Many Requests | Rate limit exceeded |
| 500 | Internal Server Error | Server error (rare) |

## Rate Limiting

- **Limit:** 1000 requests per hour per token
- **Headers:** Response includes `X-RateLimit-Remaining` and `X-RateLimit-Reset`
- **Retry:** When limit reached, wait until `X-RateLimit-Reset` timestamp

## Related Documentation

- [Patient Data Model](link) - Complete field reference
- [API Architecture Overview](link) - Design decisions and rationale
- [OAuth Setup Guide](link) - Token generation and security
- [Patient Portal Deployment Guide](link) - Development and production setup
- [API Status & Incidents](link) - Current system status
```

---

## Reference Documentation Best Practices

### Precision
- Use exact names, types, and formats from implementation
- Include all required vs. optional fields
- Link to authoritative sources (Swagger, GitHub)

### Discoverability
- Include table of contents for long docs
- Use consistent heading structure
- Link related documentation at bottom

### Maintenance
- Include version numbers for APIs
- Mark deprecated fields clearly
- Update regularly when API changes

### Examples
- Include complete request/response examples
- Show both success and error cases
- Use realistic, representative data

---

**Template Version:** 1.0
**Last Updated:** February 3, 2026
**Based on:** Notion Page Analysis & Template Guide
