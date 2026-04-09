# CreateTask Workflow

Convert an email thread into a structured task proposal.

## Voice Notification

```bash
curl -s -X POST http://localhost:8888/notify \
  -H "Content-Type: application/json" \
  -d '{"message": "Creating task from email"}' \
  > /dev/null 2>&1 &
```

## Step 1: Extract Task Information

From the email thread, extract:
- **What** needs to be done (the actual deliverable or action)
- **Who** is responsible
- **When** it's due (if implied or stated)
- **Which project** or workstream it belongs to
- **Dependencies** or blockers
- **Source context** (brief thread summary)

## Step 2: Build Task Proposal

```
TASK PROPOSAL:

Title: [Action-oriented title — verb first]
Project: [Project or workstream, if inferable]
Next Action: [The specific next physical action to take]
Due Date: [Date if implied, otherwise "No deadline stated"]
Source: [1-2 sentence thread summary]
Dependencies: [If any]

---

AWAITING YOUR DECISION:
- approve (creates task record)
- put under [project name]
- change due date to [date]
- edit title
- cancel
```

## Task Title Rules

- Start with a verb: "Review", "Send", "Prepare", "Follow up on", "Schedule"
- Be specific: "Review Q2 budget proposal" not "Budget stuff"
- Keep under 80 characters

## Step 3: Wait for Approval

Do NOT create the task until the user approves. They may:
- Approve as-is
- Modify project assignment
- Change due date
- Edit the title or next action
- Cancel

## Step 4: Record the Task

On approval, output the finalized task in a format ready for the user's task system. If Telos skills are available, route to the appropriate project.
