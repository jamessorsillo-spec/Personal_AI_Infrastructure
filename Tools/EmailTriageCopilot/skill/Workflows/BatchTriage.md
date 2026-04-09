# BatchTriage Workflow

Process multiple emails across multiple accounts using the GTD triage framework.

## Voice Notification

```bash
curl -s -X POST http://localhost:8888/notify \
  -H "Content-Type: application/json" \
  -d '{"message": "Starting batch email triage"}' \
  > /dev/null 2>&1 &
```

## Connected Accounts

Four Gmail accounts are available via MCP. See `accounts.json` or `~/.claude/PAI/USER/WORK/EMAIL.md` for full config.

| Server | Account | Context | Priority |
|--------|---------|---------|----------|
| `gmail-tetrascience` | jorsillo@tetrascience.com | Work (TetraScience) | 1 |
| `gmail-underscore` | james@underscore.vc | Underscore VC | 2 |
| `gmail-personal` | james.s.orsillo@gmail.com | Personal | 3 |
| `gmail-jimmyors` | jimmyors75@gmail.com | Personal 2 | 4 |

## Step 1: Fetch Emails

### Multi-Account Mode (default)

Process accounts in priority order. For each account:
1. Use that account's MCP server `gmail_search_messages` with query `is:unread`
2. Fetch up to 20 threads per account
3. For each result, use `gmail_read_thread` to get full thread content
4. Tag each thread with its source account for context

**Account selection:**
- `process inbox` / `triage all` → All accounts in priority order
- `triage work` / `triage tetrascience` → TetraScience only
- `triage underscore` / `triage vc` → Underscore VC only
- `triage personal` → Personal only
- `triage jimmyors` → Personal 2 only

### Single Account Mode

User specifies which account: "triage my TetraScience inbox"

### No Gmail MCP

- Ask user to paste emails one at a time
- Or accept a batch of emails in structured format

## Step 2: Triage Each Thread

For each thread, run the full Triage workflow:
1. Classify using GTD states
2. Prepare the artifact
3. Present the triage card

## Step 3: Present Triage Card

For each email, show a compact triage card with account badge:

```
[1/12] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ACCOUNT: [TetraScience | Underscore VC | Personal | Personal 2]

From: [sender]
Subject: [subject]
State: [TRIAGE STATE]

WHY: [1-line summary]

NEXT: [recommended action]

PREPARED: [short artifact preview]

> reply | task | waiting for | archive | reference | skip | stop | next account
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

Accounts processed: 4
Total threads: 37

By account:
  TetraScience:   15 threads
  Underscore VC:   8 threads
  Personal:       10 threads
  Personal 2:      4 threads

By state:
  DO-NOW: 5 (replies drafted)
  TASK: 12 (tasks proposed)
  WAITING-FOR: 6 (follow-ups set)
  REFERENCE: 4
  ARCHIVE: 8
  REVIEW-REQUIRED: 2
  Skipped: 0

Pending actions requiring your approval:
1. [list any drafts, tasks, follow-ups awaiting confirmation]
```

## Performance Notes

- In batch mode, keep triage cards compact
- Skip lengthy analysis for obvious archive/reference emails
- Flag REVIEW-REQUIRED items but don't block the batch on them
- Track position so the user can resume if interrupted
