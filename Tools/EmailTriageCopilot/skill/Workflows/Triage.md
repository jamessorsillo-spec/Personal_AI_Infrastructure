# Triage Workflow

Classify a single email thread using the GTD framework.

## Voice Notification

```bash
curl -s -X POST http://localhost:8888/notify \
  -H "Content-Type: application/json" \
  -d '{"message": "Triaging email thread"}' \
  > /dev/null 2>&1 &
```

## Step 1: Receive the Thread

Accept the email thread from one of these sources:
- **Pasted text** — User pastes the email directly
- **Gmail MCP** — If Gmail MCP tools are available, fetch via `gmail_read_thread` or `gmail_read_message`
- **Cloud API** — Call `arbol-a-triage-email` worker if operating remotely

## Step 2: Run Triage

If running locally (Claude Code session), apply the GTD framework from `GtdFramework.md` directly.

If running via cloud API:
```bash
curl -X POST https://arbol-a-triage-email.YOUR-SUBDOMAIN.workers.dev/ \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "thread": "[full thread text]",
    "sender": "[sender]",
    "subject": "[subject]"
  }'
```

## Step 3: Present Results

Output in the standard triage format:

```
TRIAGE STATE: [state]

WHY IT MATTERS:
- [bullets]

RECOMMENDED NEXT ACTION:
- [action]

PREPARED OUTPUT:
[artifact]

RISK FLAGS:
- [if any]

AWAITING YOUR DECISION:
- [command options]
```

## Step 4: Wait for User Command

Do NOT proceed until the user gives an explicit command. Valid commands:

- `reply` / `draft reply` → Switch to DraftReply workflow
- `make this a task` → Switch to CreateTask workflow
- `waiting for [person]` → Switch to FollowUp workflow
- `archive` → Confirm archive
- `reference` → Propose label/folder
- `review` → Escalate as REVIEW-REQUIRED
- `next` → Move to next email (in batch mode)
