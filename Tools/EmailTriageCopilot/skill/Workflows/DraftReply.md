# DraftReply Workflow

Draft an email reply based on triage context and user instruction.

## Voice Notification

```bash
curl -s -X POST http://localhost:8888/notify \
  -H "Content-Type: application/json" \
  -d '{"message": "Drafting email reply"}' \
  > /dev/null 2>&1 &
```

## Step 1: Gather Context

Required:
- The email thread (from prior triage or freshly provided)
- User instruction (what to say, how to respond)

Optional:
- Triage state from prior classification
- Tone modifier (warmer, firmer, shorter, formal, casual)

## Step 2: Draft the Reply

If running locally, apply these rules directly:
- Concise, professional, direct
- Do not over-commit
- Do not invent facts
- Do not imply approvals not given
- Match formality of original thread
- If key facts are missing, flag them explicitly

If running via cloud API:
```bash
curl -X POST https://arbol-a-draft-email-reply.YOUR-SUBDOMAIN.workers.dev/ \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "thread": "[thread text]",
    "instruction": "[user instruction]",
    "subject": "[subject]",
    "tone": "[optional tone]"
  }'
```

## Step 3: Present Draft

```
DRAFT REPLY:

Subject: Re: [subject]

[draft text]

---
NOTES: [any flags about missing info or risks]

AWAITING YOUR DECISION:
- send (creates Gmail draft or sends)
- shorten this draft
- make it warmer
- make it firmer
- rewrite with [instruction]
- cancel
```

## Step 4: Iterate or Execute

- If user says `send` → Create Gmail draft via MCP if available, or present final text
- If user gives tone/content adjustment → Re-draft with modifier
- If user says `cancel` → Return to triage

## Gmail MCP Integration

When Gmail MCP tools are available:
- `gmail_create_draft` — Create draft in Gmail for user review
- The draft is NOT sent — user must send manually from Gmail

**Never send email directly. Always create as draft.**
