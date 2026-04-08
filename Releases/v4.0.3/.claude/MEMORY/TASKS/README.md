# MEMORY/TASKS — Apple Notes Task Sync

This directory bridges your Apple Notes task list with PAI, making it available
across both local terminal and web Claude Code sessions.

## How It Works

```
Apple Notes (Mac)
       │
       ▼ (osascript export OR Apple Shortcut)
master-tasks.md  ← canonical task file
       │
       ▼ (git commit + push)
Available everywhere (local, web, cowork)
       │
       ▼ (SessionStart hook)
Auto-loaded into Claude's context
```

## Sync Methods

### 1. Shell Script (Mac Terminal)

```bash
# Sync default note ("Master Task List")
~/.claude/Tools/apple-notes-sync.sh

# Sync a specific note
~/.claude/Tools/apple-notes-sync.sh "My Tasks"

# Sync from a specific folder
~/.claude/Tools/apple-notes-sync.sh --note "Q2 Tasks" --folder "Work"

# Sync and auto-push to git
~/.claude/Tools/apple-notes-sync.sh --push

# List all your notes
~/.claude/Tools/apple-notes-sync.sh --list
```

### 2. Apple Shortcut (iPhone/iPad/Mac — recommended for automation)

Create an Apple Shortcut with these steps:

1. **Find Notes** → filter by name = "Master Task List"
2. **Get Body of Note** → extracts content
3. **Run Shell Script** (Mac) or **Save to Files** (iOS):
   - Mac: write to `~/.claude/MEMORY/TASKS/master-tasks.md`
   - iOS: save to iCloud Drive → pick up via iCloud sync on Mac
4. Optional: **Run Shell Script** → `cd ~/Personal_AI_Infrastructure && git add . && git commit -m "sync: tasks" && git push`

Trigger options:
- Automation: run daily at a specific time
- Manual: add to Home Screen for one-tap sync
- Siri: "Hey Siri, sync my tasks"

### 3. Claude Code Terminal (direct, when MCP available)

When running Claude Code locally on Mac with an Apple Notes MCP server:
```
"Sync my Apple Notes task list to PAI"
```
Claude will use the MCP to read the note and write master-tasks.md directly.

## File Format

`master-tasks.md` uses this structure:

```markdown
---
source: apple-notes
note_name: "Master Task List"
synced_at: 2026-04-08T12:00:00Z
sync_method: osascript
---

# Master Task List

> Synced from Apple Notes: "Master Task List" on 2026-04-08T12:00:00Z

[Your task content in markdown...]
```

## Integration with PAI

- **SessionStart**: The `LoadAppleNotesTasks.hook.ts` auto-loads `master-tasks.md`
  into Claude's context as a `<system-reminder>` block
- **Context**: Tasks appear in every session (local and web) so Claude always
  knows what you're working on
- **Updates**: Edit tasks in Apple Notes, re-sync, commit, push — next session picks it up

## Task Format Tips

For best results in Apple Notes, use:
- **Checklists** (built-in Apple Notes feature) — converted to `- [ ]` / `- [x]`
- **Headers** for categories — converted to `## Category`
- **Bold** for priorities — converted to `**priority**`
