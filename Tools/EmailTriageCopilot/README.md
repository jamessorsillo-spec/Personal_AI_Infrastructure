# Email Triage Copilot

GTD-based email triage agent, deployable as Cloudflare Workers and usable as a PAI skill.

Human-in-the-loop only — recommends and prepares, never acts without explicit approval.

## Architecture

```
EmailTriageCopilot/
├── actions/                    # PAI Actions (local execution)
│   ├── A_TRIAGE_EMAIL/         # Classify thread using GTD framework
│   └── A_DRAFT_EMAIL_REPLY/    # Draft reply with tone control
├── workers/                    # Cloudflare Workers (cloud API)
│   ├── a-triage-email/         # HTTP endpoint for triage
│   └── a-draft-email-reply/    # HTTP endpoint for drafting
├── skill/                      # PAI Skill (Claude Code interface)
│   ├── SKILL.md                # Skill definition + routing
│   ├── GtdFramework.md         # Complete GTD classification system
│   └── Workflows/              # Execution procedures
│       ├── Triage.md           # Single-thread triage
│       ├── DraftReply.md       # Reply drafting with iteration
│       ├── CreateTask.md       # Email → task conversion
│       ├── FollowUp.md         # Waiting-for tracking
│       └── BatchTriage.md      # Process multiple emails
├── pipeline/                   # PAI Pipeline definition
│   └── PIPELINE.md             # P_EMAIL_TRIAGE: triage + optional draft
├── deploy.sh                   # Cloudflare deployment script
└── README.md                   # This file
```

## Classification States

| State | Meaning |
|-------|---------|
| **DO-NOW** | Reply or act now; straightforward |
| **TASK** | Requires work, research, or coordination |
| **WAITING-FOR** | Someone else owes a response |
| **REFERENCE** | Useful info, no action needed |
| **ARCHIVE** | No action, low future value |
| **REVIEW-REQUIRED** | Sensitive, risky, or ambiguous |

## Quick Start

### Use from Claude Code (PAI Skill)

Copy the skill into your PAI installation:

```bash
cp -r skill/ ~/.claude/skills/Utilities/EmailTriage/
```

Then invoke:
```
/email-triage [paste email thread]
```

Or in conversation:
```
triage this email: [paste thread]
```

### Use via Cloud API

#### 1. Deploy Workers

```bash
# Install wrangler if needed
npm install -g wrangler

# Deploy
bash deploy.sh all

# Set secrets (AUTH_TOKEN + ANTHROPIC_API_KEY)
bash deploy.sh secrets
```

#### 2. Triage an Email

```bash
curl -X POST https://arbol-a-triage-email.YOUR-SUBDOMAIN.workers.dev/ \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "thread": "Hey James, can you review the Q2 budget proposal by Friday? The board needs it for Monday. Thanks, Sarah",
    "sender": "sarah@company.com",
    "subject": "Q2 Budget Review"
  }'
```

Response:
```json
{
  "success": true,
  "action": "A_TRIAGE_EMAIL",
  "duration_ms": 1842,
  "output": {
    "triage_state": "TASK",
    "why_it_matters": [
      "Board deadline Monday — review needed by Friday",
      "You owe Sarah a deliverable"
    ],
    "recommended_action": "Create task: Review Q2 budget proposal, due Friday",
    "prepared_output": {
      "title": "Review Q2 budget proposal",
      "project": "Finance",
      "next_action": "Open budget proposal and complete review",
      "due_date": "Friday",
      "source_summary": "Sarah requesting Q2 budget review for Monday board meeting"
    },
    "risk_flags": [],
    "commands": ["make task", "reply", "review", "snooze until Thursday"]
  }
}
```

#### 3. Draft a Reply

```bash
curl -X POST https://arbol-a-draft-email-reply.YOUR-SUBDOMAIN.workers.dev/ \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "thread": "[email thread]",
    "instruction": "Confirm I will review by Thursday EOD",
    "subject": "Q2 Budget Review",
    "sender": "sarah@company.com"
  }'
```

#### 4. Health Check

```bash
bash deploy.sh health
```

## Install Actions into PAI

```bash
# Copy actions to your PAI USER/ACTIONS directory
cp -r actions/A_TRIAGE_EMAIL/ ~/.claude/PAI/USER/ACTIONS/
cp -r actions/A_DRAFT_EMAIL_REPLY/ ~/.claude/PAI/USER/ACTIONS/

# Test locally
cd ~/.claude/PAI/ACTIONS
bun lib/runner.v2.ts run A_TRIAGE_EMAIL --input '{"thread": "test email content"}'
```

## Install Pipeline

```bash
cp -r pipeline/ ~/.claude/PAI/USER/PIPELINES/Email_Triage/
```

## Gmail MCP Integration

When Gmail MCP tools are connected in Claude Code, the skill can:
- Fetch threads directly via `gmail_read_thread`
- Search inbox via `gmail_search_messages`
- Create drafts via `gmail_create_draft` (never sends directly)

## Secrets Required

| Secret | Purpose |
|--------|---------|
| `AUTH_TOKEN` | Bearer token for worker authentication |
| `ANTHROPIC_API_KEY` | Claude API access for LLM triage |

## Shorthand Commands

During triage, use these commands:

| Command | Action |
|---------|--------|
| `reply` | Draft a reply |
| `task` | Create task proposal |
| `waiting for [person]` | Track follow-up |
| `archive` | Archive the thread |
| `reference` | File as reference |
| `review` | Flag for manual review |
| `shorten` | Shorten a draft |
| `warmer` / `firmer` | Adjust draft tone |
| `next` | Skip to next (batch mode) |
| `stop` | End batch processing |
