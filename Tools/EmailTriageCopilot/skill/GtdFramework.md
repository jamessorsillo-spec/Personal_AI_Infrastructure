# GTD Email Triage Framework

## Classification States

Every thread must be classified into exactly one state:

| State | When to Use |
|-------|-------------|
| **DO-NOW** | Reply or act now; response is straightforward |
| **TASK** | Requires work, research, preparation, or coordination |
| **WAITING-FOR** | Someone else owes a response; delegated; needs follow-up reminder |
| **REFERENCE** | Useful information, no current action |
| **ARCHIVE** | No action, no meaningful future value |
| **REVIEW-REQUIRED** | Sensitive, ambiguous, risky, or high consequence |

## REVIEW-REQUIRED Triggers

Classify as REVIEW-REQUIRED when the email involves:
- Legal matters
- Finance approvals
- Pricing or commercial commitments
- Investor communication
- HR or personnel matters
- Security, compliance, or regulatory issues
- Sensitive customer escalations
- Emotionally charged communication
- Ambiguity about what is being asked
- Any situation where the wrong response could create material risk

## Triage Workflow

### Step 1: Understand the Thread

Extract:
- Sender and relevant participants
- What they want
- Whether a response is owed
- Whether there is a decision, commitment, or follow-up
- Whether this belongs to an existing project
- Whether it should become a task
- Whether it is reference only
- Whether it is risky or sensitive

### Step 2: Classify

Assign exactly one triage state.

### Step 3: Recommend One Next Action

Pick the single clearest next step:
- Draft reply
- Create task
- Create waiting-for follow-up
- Label/file as reference
- Archive
- Snooze
- Hold for review

### Step 4: Prepare the Artifact

| State | Artifact |
|-------|----------|
| DO-NOW | Draft concise reply |
| TASK | Task proposal: title, project, next action, due date, source summary |
| WAITING-FOR | Follow-up proposal: owner, what waiting on, follow-up date, reason |
| REFERENCE | Proposed label/folder treatment |
| ARCHIVE | Propose archive with reason |
| REVIEW-REQUIRED | Issue summary, risk assessment, decision required |

### Step 5: Wait

Stop and wait for user instruction.

## Required Output Format

```
TRIAGE STATE: [state]

WHY IT MATTERS:
- bullet 1
- bullet 2
- bullet 3

RECOMMENDED NEXT ACTION:
- one clear action

PREPARED OUTPUT:
[artifact based on state]

RISK FLAGS:
- only if relevant

AWAITING YOUR DECISION:
- command option 1
- command option 2
- command option 3
```

## Default Assumptions

- Preserve commitments
- Prefer task creation over leaving work trapped in inbox
- Prefer waiting-for tracking when someone else owes a response
- Prefer reference over archive when future context may matter
- Prefer review-required over improvisation when risk is elevated

## Draft Reply Rules

- Concise, professional, direct
- Do not over-commit
- Do not invent facts
- Do not imply approvals not given
- Flag missing information explicitly

## Allowed Without Approval

- Summarize, classify, explain, recommend
- Draft replies, forwards, task proposals, follow-up items
- Suggest project routing, labels, folders, archive, snooze

## NOT Allowed Without Explicit Approval

- Send replies or forwards
- Archive, snooze, move, label, delete
- Create tasks in external systems
- Mark anything complete
