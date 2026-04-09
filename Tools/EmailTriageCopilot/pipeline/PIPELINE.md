# P_EMAIL_TRIAGE Pipeline

**Purpose:** Triage an email thread and optionally draft a reply in one pass
**Domain:** Email
**Version:** 1.0

---

## Pipeline Overview

| Step | Action | Purpose |
|------|--------|---------|
| 1 | A_TRIAGE_EMAIL | Classify the thread using GTD framework |
| 2 | A_DRAFT_EMAIL_REPLY | Draft a reply if triage state is DO-NOW (conditional) |

## Data Flow

```
Input:
  thread (required)
  sender, subject, context (optional)
  instruction (optional — if provided, forces draft reply)

Step 1 — A_TRIAGE_EMAIL:
  Reads: thread, sender, subject, context
  Adds: triage_state, why_it_matters, recommended_action, prepared_output, risk_flags, commands

Step 2 — A_DRAFT_EMAIL_REPLY (conditional):
  Condition: triage_state == "DO-NOW" OR instruction is provided
  Reads: thread, sender, subject, triage_state, instruction
  Adds: draft_reply, draft_subject, notes
```

## Arbol YAML Definition

```yaml
name: P_EMAIL_TRIAGE
description: Triage email thread with optional reply draft
actions:
  - A_TRIAGE_EMAIL
  - A_DRAFT_EMAIL_REPLY
```

## Cloud Deployment

Worker: `arbol-p-email-triage`

```jsonc
// wrangler.jsonc
{
  "name": "arbol-p-email-triage",
  "main": "src/index.ts",
  "compatibility_date": "2026-01-30",
  "compatibility_flags": ["nodejs_compat"],
  "services": [
    { "binding": "A_TRIAGE_EMAIL", "service": "arbol-a-triage-email" },
    { "binding": "A_DRAFT_EMAIL_REPLY", "service": "arbol-a-draft-email-reply" }
  ]
}
```

## Local Execution

```bash
cd ~/.claude/PAI/ACTIONS
bun lib/pipeline-runner.ts run P_EMAIL_TRIAGE \
  --input '{"thread": "...", "subject": "...", "sender": "..."}'
```
