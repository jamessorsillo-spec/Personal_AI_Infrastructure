# FollowUp Workflow

Create a waiting-for or follow-up tracking entry from an email thread.

## Voice Notification

```bash
curl -s -X POST http://localhost:8888/notify \
  -H "Content-Type: application/json" \
  -d '{"message": "Creating follow-up tracker"}' \
  > /dev/null 2>&1 &
```

## Step 1: Identify the Follow-Up

Determine:
- **Who** owns the next step (not the user — someone else)
- **What** the user is waiting on
- **When** to follow up (suggest a date based on context)
- **Why** that date (urgency, deadline, convention)

## Step 2: Build Follow-Up Proposal

```
WAITING-FOR:

Owner: [Person who owes the next step]
Waiting On: [What specifically we're waiting for]
Follow-Up Date: [Suggested date]
Reason: [Why this date — deadline proximity, business convention, urgency]
Source: [1-2 sentence thread summary]

---

AWAITING YOUR DECISION:
- approve
- change follow-up to [date]
- waiting for [different person]
- also make a task
- cancel
```

## Follow-Up Date Guidelines

- If a deadline is stated: follow up 2-3 business days before
- If no deadline: follow up in 5 business days
- If urgent: follow up in 1-2 business days
- If user says "remind me [date]": use that date exactly

## Step 3: Wait for Approval

Do NOT create the follow-up entry until the user approves.

## Step 4: Record

On approval, output the finalized follow-up entry. If snooze behavior is requested, note the snooze date.
