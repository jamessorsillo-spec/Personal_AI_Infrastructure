# Release Playbook — Email Triage Copilot

Step-by-step instructions to get the Email Triage Copilot running in your daily workflow via Claude Code (cowork).

---

## Step 1: Merge the Branch

The code is on branch `claude/email-triage-copilot-R1Rga`. Merge it to main:

```bash
cd ~/Personal_AI_Infrastructure
git checkout main
git merge claude/email-triage-copilot-R1Rga
git push origin main
```

Or create a PR if you prefer review first.

---

## Step 2: Install the PAI Skill

Copy the skill into your PAI installation so Claude Code discovers it:

```bash
# From the repo root
cp -r Tools/EmailTriageCopilot/skill/ ~/.claude/skills/Utilities/EmailTriage/
```

This makes the skill available via `/email-triage` or natural language ("triage my inbox").

---

## Step 3: Install the Actions

```bash
cp -r Tools/EmailTriageCopilot/actions/A_TRIAGE_EMAIL/ ~/.claude/PAI/USER/ACTIONS/
cp -r Tools/EmailTriageCopilot/actions/A_DRAFT_EMAIL_REPLY/ ~/.claude/PAI/USER/ACTIONS/
```

---

## Step 4: Install the Email Context

```bash
cp Tools/EmailTriageCopilot/../../Releases/v4.0.3/.claude/PAI/USER/WORK/EMAIL.md ~/.claude/PAI/USER/WORK/EMAIL.md
```

This gives your chief of staff persistent awareness of your 4 Gmail accounts and their priority order.

---

## Step 5: Add CLAUDE.md to Your Cowork Session

The file `Tools/EmailTriageCopilot/CLAUDE.md` contains the complete triage copilot instructions. You have two options:

### Option A: Append to your existing CLAUDE.md

```bash
echo "" >> ~/.claude/CLAUDE.md
cat Tools/EmailTriageCopilot/CLAUDE.md >> ~/.claude/CLAUDE.md
```

### Option B: Use as a standalone session prompt

Copy/paste the contents of `CLAUDE.md` into a new Claude Code web session when you want to do email triage.

---

## Step 6: Verify Gmail MCP Connections

In Claude Code (cowork), verify all 4 Gmail MCP servers are connected:

1. Check that you see these MCP servers in your settings:
   - `gmail-tetrascience`
   - `gmail-underscore`
   - `gmail-personal`
   - `gmail-jimmyors`

2. Test each connection by asking Claude Code:
   ```
   Check my TetraScience inbox for unread count
   Check my Underscore VC inbox for unread count
   Check my personal inbox for unread count
   Check my jimmyors inbox for unread count
   ```

If any server is disconnected, re-authenticate using the OAuth credentials stored in your `.env`.

---

## Step 7: First Triage Session

Open Claude Code (cowork) and say:

```
triage my inbox
```

This will:
1. Sweep all 4 accounts in priority order (TetraScience → Underscore → Personal → jimmyors)
2. Present triage cards for each unread thread
3. Wait for your command on each one
4. Show a summary when done

### Quick commands during triage:

| Say | Does |
|-----|------|
| `reply` | Drafts a reply |
| `send` | Creates Gmail draft (you send from Gmail) |
| `task` | Creates task proposal |
| `waiting for [person]` | Tracks follow-up |
| `archive` | Archives |
| `skip` / `next` | Next thread |
| `next account` | Skip to next Gmail account |
| `stop` | End session |

---

## Step 8 (Optional): Deploy Cloud Workers

If you want HTTP API access (callable from scripts, shortcuts, automations):

```bash
cd ~/Personal_AI_Infrastructure/Tools/EmailTriageCopilot

# Deploy both workers to Cloudflare
bash deploy.sh all

# Set secrets (AUTH_TOKEN + ANTHROPIC_API_KEY)
bash deploy.sh secrets

# Verify
bash deploy.sh health
```

After deployment, you can triage via curl:

```bash
curl -X POST https://arbol-a-triage-email.YOUR-SUBDOMAIN.workers.dev/ \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"thread": "...", "subject": "...", "sender": "..."}'
```

---

## Step 9: Rotate Your OAuth Secret

**IMPORTANT:** Your OAuth Client Secret was exposed in a conversation. Rotate it:

1. Go to Google Cloud Console → APIs & Credentials → OAuth 2.0 Client IDs
2. Find the "PAI Chief of Staff" client
3. Click "Reset Secret"
4. Update the secret in your `.env` and re-authenticate all 4 Gmail MCP servers

---

## Daily Workflow

1. Open Claude Code (cowork)
2. Say: `triage my inbox` (or `triage work` for TetraScience only)
3. Process each card with one-word commands
4. End with `stop` — get your summary
5. Time target: 10-15 minutes for a full 4-account sweep

---

## File Inventory

| File | Purpose | Install Location |
|------|---------|-----------------|
| `skill/SKILL.md` | PAI skill definition | `~/.claude/skills/Utilities/EmailTriage/SKILL.md` |
| `skill/GtdFramework.md` | GTD classification reference | `~/.claude/skills/Utilities/EmailTriage/GtdFramework.md` |
| `skill/Workflows/*.md` | 5 execution workflows | `~/.claude/skills/Utilities/EmailTriage/Workflows/` |
| `actions/A_TRIAGE_EMAIL/` | Triage action | `~/.claude/PAI/USER/ACTIONS/A_TRIAGE_EMAIL/` |
| `actions/A_DRAFT_EMAIL_REPLY/` | Draft action | `~/.claude/PAI/USER/ACTIONS/A_DRAFT_EMAIL_REPLY/` |
| `pipeline/PIPELINE.md` | Pipeline definition | `~/.claude/PAI/USER/PIPELINES/Email_Triage/` |
| `CLAUDE.md` | Copilot instructions | Append to `~/.claude/CLAUDE.md` or use standalone |
| `accounts.json` | Account registry | Reference only |
| `mcp-servers.json` | MCP server config template | Reference for Claude Code settings |
| `deploy.sh` | Cloudflare deployment | Run from repo |
| `install.sh` | PAI installer | Run from repo |
