# BatchTriage Workflow

Process multiple emails in sequence using the GTD triage framework.

## Voice Notification

```bash
curl -s -X POST http://localhost:8888/notify \
  -H "Content-Type: application/json" \
  -d '{"message": "Starting batch email triage"}' \
  > /dev/null 2>&1 &
```

## Step 1: Fetch Emails

If Gmail MCP tools are available:
- Use `gmail_search_messages` with query `is:unread` (or user-specified query)
- Fetch up to 20 threads at a time
- For each result, use `gmail_read_thread` to get full thread content

If no Gmail MCP:
- Ask user to paste emails one at a time
- Or accept a batch of emails in structured format

## Step 2: Triage Each Thread

For each thread, run the full Triage workflow:
1. Classify using GTD states
2. Prepare the artifact
3. Present the triage card

## Step 3: Present Triage Card

For each email, show a compact triage card:

```
[1/12] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

From: [sender]
Subject: [subject]
State: [TRIAGE STATE]

WHY: [1-line summary]

NEXT: [recommended action]

PREPARED: [short artifact preview]

> reply | task | waiting for | archive | reference | skip | stop
```

## Step 4: Process User Command

After each card, wait for the user's command:

- `reply` → Run DraftReply workflow, then return to batch
- `task` → Run CreateTask workflow, then return to batch
- `waiting for [person]` → Run FollowUp workflow, then return to batch
- `archive` → Mark for archive, move to next
- `reference` → Mark for reference, move to next
- `skip` / `next` → Move to next email
- `stop` → End batch processing

## Step 5: Summary

After all emails are processed (or user stops), show a summary:

```
BATCH TRIAGE COMPLETE

Processed: 12 threads
- DO-NOW: 3 (replies drafted)
- TASK: 4 (tasks proposed)
- WAITING-FOR: 2 (follow-ups set)
- REFERENCE: 1
- ARCHIVE: 2
- REVIEW-REQUIRED: 0
- Skipped: 0

Pending actions requiring your approval:
1. [list any drafts, tasks, follow-ups awaiting confirmation]
```

## Performance Notes

- In batch mode, keep triage cards compact
- Skip lengthy analysis for obvious archive/reference emails
- Flag REVIEW-REQUIRED items but don't block the batch on them
- Track position so the user can resume if interrupted
