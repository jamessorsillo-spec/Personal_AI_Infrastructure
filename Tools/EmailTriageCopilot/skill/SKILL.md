---
name: EmailTriage
description: GTD-based email triage copilot — classify threads, draft replies, create tasks, track follow-ups. Human-in-the-loop only. USE WHEN email triage, triage inbox, process email, email GTD, draft reply, email task, waiting for follow-up, email review, inbox zero, email copilot OR email classification OR process my inbox.
---

## Customization

**Before executing, check for user customizations at:**
`~/.claude/PAI/USER/SKILLCUSTOMIZATIONS/EmailTriage/`

If this directory exists, load and apply any PREFERENCES.md, configurations, or resources found there. These override default behavior. If the directory does not exist, proceed with skill defaults.

## MANDATORY: Voice Notification (REQUIRED BEFORE ANY ACTION)

**You MUST send this notification BEFORE doing anything else when this skill is invoked.**

1. **Send voice notification**:
   ```bash
   curl -s -X POST http://localhost:8888/notify \
     -H "Content-Type: application/json" \
     -d '{"message": "Running the email triage copilot"}' \
     > /dev/null 2>&1 &
   ```

2. **Output text notification**:
   ```
   Running the **EmailTriage** skill...
   ```

# EmailTriage

GTD-based email triage copilot. Reads threads, classifies them, proposes the next step, prepares drafts or task structures, and waits for your instruction before taking any action.

**Core principle: You stay in control.** This skill recommends and prepares — it does not send, archive, label, or create tasks without explicit approval.

## Framework Reference

See `GtdFramework.md` in this skill directory for the complete classification system, workflow, and output format.

## Cloud API

When deployed as Arbol workers, this skill is accessible via HTTP:

| Endpoint | Worker | Purpose |
|----------|--------|---------|
| `POST /` | `arbol-a-triage-email` | Triage a thread |
| `POST /` | `arbol-a-draft-email-reply` | Draft a reply |

See `~/Personal_AI_Infrastructure/Tools/EmailTriageCopilot/` for worker source and deployment instructions.

## Workflow Routing

| Workflow | Trigger | File |
|----------|---------|------|
| **Triage** | "triage this email", "process this thread", "classify email" | `Workflows/Triage.md` |
| **DraftReply** | "draft reply", "reply to this", "write a response" | `Workflows/DraftReply.md` |
| **CreateTask** | "make this a task", "create task from email", "task" | `Workflows/CreateTask.md` |
| **FollowUp** | "waiting for", "follow up", "remind me", "snooze" | `Workflows/FollowUp.md` |
| **BatchTriage** | "process inbox", "triage my inbox", "batch triage" | `Workflows/BatchTriage.md` |

## Shorthand Commands

The user may issue these commands at any point during triage:

| Command | Action |
|---------|--------|
| `reply` / `draft reply` | Draft a reply for approval |
| `make this a task` | Create a task proposal |
| `waiting for [person]` | Create a waiting-for follow-up |
| `remind me [date]` | Snooze / follow-up proposal |
| `archive` | Propose archive |
| `reference` | Propose reference filing |
| `review` | Flag as REVIEW-REQUIRED |
| `shorten this draft` | Shorten a prepared draft |
| `make it warmer` | Adjust draft tone warmer |
| `make it firmer` | Adjust draft tone firmer |
| `forward to [name]` | Draft a forward |
| `summarize in one sentence` | One-line summary |

## Examples

**Example 1: Triage a pasted email**
```
User: "triage this email: [pastes email thread]"
-> Invokes Triage workflow
-> Returns: classification, why it matters, recommended action, prepared artifact
-> Waits for user command (reply, task, archive, etc.)
```

**Example 2: Draft a reply after triage**
```
User: "draft reply"
-> Invokes DraftReply workflow using last triaged thread context
-> Returns: draft reply for approval
-> User says "send" or "make it shorter" etc.
```

**Example 3: Batch inbox processing**
```
User: "process my inbox"
-> Invokes BatchTriage workflow
-> Fetches unread emails, triages each one
-> Presents triage cards one at a time, waits for command on each
```
