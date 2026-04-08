#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# Apple Notes → PAI Task Sync
# ═══════════════════════════════════════════════════════════════════════════════
#
# Exports Apple Notes to markdown files that PAI can read across both local
# terminal and web sessions (via git).
#
# Features:
#   - Change detection: skips sync if note hasn't been modified
#   - Task triage: separates open vs completed tasks, archives old completions
#   - Multi-note: sync a single note or all notes in a folder
#
# USAGE:
#   ./apple-notes-sync.sh                          # Uses default note name
#   ./apple-notes-sync.sh "My Task List"           # Specify note name
#   ./apple-notes-sync.sh --note "My Task List"    # Explicit flag
#   ./apple-notes-sync.sh --folder "Work"          # Sync ALL notes in folder
#   ./apple-notes-sync.sh --push                   # Auto git commit+push after sync
#   ./apple-notes-sync.sh --force                  # Skip change detection
#   ./apple-notes-sync.sh --list                   # List all notes (for discovery)
#
# REQUIREMENTS:
#   - macOS (uses osascript/AppleScript)
#   - Apple Notes app with the target note
#
# OUTPUT:
#   ~/.claude/MEMORY/TASKS/master-tasks.md           (single note mode)
#   ~/.claude/MEMORY/TASKS/{slug}.md                 (folder mode)
#   ~/.claude/MEMORY/TASKS/.sync-state.json          (change tracking)
#
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────

PAI_DIR="${PAI_DIR:-$HOME/.claude}"
TASKS_DIR="${PAI_DIR}/MEMORY/TASKS"
OUTPUT_FILE="${TASKS_DIR}/master-tasks.md"
SYNC_STATE_FILE="${TASKS_DIR}/.sync-state.json"
DEFAULT_NOTE_NAME="Master Task List"
NOTE_NAME=""
NOTE_FOLDER=""
FOLDER_MODE=false
AUTO_PUSH=false
LIST_MODE=false
FORCE_SYNC=false

# ── Argument Parsing ──────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --note)
      NOTE_NAME="$2"
      shift 2
      ;;
    --folder)
      NOTE_FOLDER="$2"
      FOLDER_MODE=true
      shift 2
      ;;
    --push)
      AUTO_PUSH=true
      shift
      ;;
    --force)
      FORCE_SYNC=true
      shift
      ;;
    --list)
      LIST_MODE=true
      shift
      ;;
    --help|-h)
      echo "Usage: apple-notes-sync.sh [NOTE_NAME] [--note NAME] [--folder FOLDER] [--push] [--force] [--list]"
      echo ""
      echo "Options:"
      echo "  NOTE_NAME        Name of the Apple Note to sync (positional)"
      echo "  --note NAME      Name of the Apple Note to sync (flag)"
      echo "  --folder FOLDER  Sync ALL notes in this Apple Notes folder"
      echo "  --push           Auto git commit and push after sync"
      echo "  --force          Skip change detection, always re-sync"
      echo "  --list           List all notes and exit"
      echo "  --help           Show this help"
      exit 0
      ;;
    *)
      # Positional argument = note name
      NOTE_NAME="$1"
      shift
      ;;
  esac
done

NOTE_NAME="${NOTE_NAME:-$DEFAULT_NOTE_NAME}"

# ── Platform Check ────────────────────────────────────────────────────────────

if [[ "$(uname)" != "Darwin" ]]; then
  echo "ERROR: This script requires macOS (Apple Notes is not available on $(uname))"
  echo ""
  echo "To sync from a non-Mac environment:"
  echo "  1. Run this script on your Mac first"
  echo "  2. It will save to ${OUTPUT_FILE}"
  echo "  3. Commit and push, then pull from your web session"
  echo ""
  echo "Or use the Apple Shortcut (see TASKS/README.md)"
  exit 1
fi

# ── Helper: slugify note name for filename ────────────────────────────────────

slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//'
}

# ── List Mode ─────────────────────────────────────────────────────────────────

if $LIST_MODE; then
  echo "Listing Apple Notes..."
  osascript -e '
    tell application "Notes"
      set noteList to {}
      repeat with aNote in notes
        set noteTitle to name of aNote
        set noteFolder to name of container of aNote
        set modDate to modification date of aNote
        set end of noteList to noteFolder & " / " & noteTitle & " (modified: " & (modDate as text) & ")"
      end repeat
      set AppleScript'\''s text item delimiters to linefeed
      return noteList as text
    end tell
  '
  exit 0
fi

# ── Change Detection ─────────────────────────────────────────────────────────
# Reads the note's modification date from Apple Notes and compares against
# our last sync timestamp. Skips export if nothing changed.

mkdir -p "$TASKS_DIR"

get_note_mod_date() {
  local name="$1"
  local folder="$2"

  if [[ -n "$folder" ]]; then
    osascript -e "
      tell application \"Notes\"
        try
          set targetFolder to folder \"${folder}\"
          set targetNote to first note of targetFolder whose name is \"${name}\"
          return (modification date of targetNote) as «class isot» as string
        on error
          return \"ERROR\"
        end try
      end tell
    " 2>/dev/null || echo "ERROR"
  else
    osascript -e "
      tell application \"Notes\"
        try
          set targetNote to first note whose name is \"${name}\"
          return (modification date of targetNote) as «class isot» as string
        on error
          return \"ERROR\"
        end try
      end tell
    " 2>/dev/null || echo "ERROR"
  fi
}

# Load sync state (tracks last-synced mod dates per note)
load_sync_state() {
  if [[ -f "$SYNC_STATE_FILE" ]]; then
    cat "$SYNC_STATE_FILE"
  else
    echo '{}'
  fi
}

save_sync_state() {
  echo "$1" > "$SYNC_STATE_FILE"
}

get_last_synced_mod() {
  local note_key="$1"
  local state="$2"
  # Simple JSON extraction via perl
  echo "$state" | perl -ne "print \$1 if /\"$(echo "$note_key" | sed 's/"/\\"/g')\"\\s*:\\s*\"([^\"]*)\"/;"
}

set_synced_mod() {
  local note_key="$1"
  local mod_date="$2"
  local state="$3"

  # If key exists, update it; otherwise add it
  if echo "$state" | grep -q "\"$note_key\""; then
    echo "$state" | perl -pe "s/\"$note_key\"\\s*:\\s*\"[^\"]*\"/\"$note_key\": \"$mod_date\"/"
  else
    # Add new key before closing brace
    echo "$state" | perl -pe "s/\\}$/,/ unless /^\\{\\s*\\}\$/; s/\\}$//" | sed 's/$//' | {
      cat
      echo "\"$note_key\": \"$mod_date\"}"
    }
  fi
}

# ── Convert HTML to Markdown ─────────────────────────────────────────────────
# Apple Notes returns HTML. We convert common patterns to markdown.

convert_to_markdown() {
  local content="$1"

  echo "$content" | perl -0777 -pe '
    # Remove HTML wrapper tags
    s/<html>//gi;
    s/<\/html>//gi;
    s/<head>.*?<\/head>//gsi;
    s/<body>//gi;
    s/<\/body>//gi;

    # Headings
    s/<h1[^>]*>(.*?)<\/h1>/# $1\n/gi;
    s/<h2[^>]*>(.*?)<\/h2>/## $1\n/gi;
    s/<h3[^>]*>(.*?)<\/h3>/### $1\n/gi;
    s/<h4[^>]*>(.*?)<\/h4>/#### $1\n/gi;

    # Bold and italic
    s/<b[^>]*>(.*?)<\/b>/**$1**/gi;
    s/<strong[^>]*>(.*?)<\/strong>/**$1**/gi;
    s/<i[^>]*>(.*?)<\/i>/*$1*/gi;
    s/<em[^>]*>(.*?)<\/em>/*$1*/gi;

    # Links
    s/<a[^>]*href="([^"]*)"[^>]*>(.*?)<\/a>/[$2]($1)/gi;

    # Checklist items (Apple Notes uses specific classes)
    s/<li[^>]*class="[^"]*checked[^"]*"[^>]*>(.*?)<\/li>/- [x] $1/gi;
    s/<li[^>]*>(.*?)<\/li>/- [ ] $1/gi;

    # Regular list items (without checkbox context)
    s/<ul[^>]*>//gi;
    s/<\/ul>//gi;
    s/<ol[^>]*>//gi;
    s/<\/ol>//gi;

    # Line breaks and paragraphs
    s/<br\s*\/?>/\n/gi;
    s/<p[^>]*>/\n/gi;
    s/<\/p>/\n/gi;
    s/<div[^>]*>/\n/gi;
    s/<\/div>/\n/gi;

    # Clean remaining tags
    s/<[^>]+>//g;

    # Decode HTML entities
    s/&amp;/&/g;
    s/&lt;/</g;
    s/&gt;/>/g;
    s/&quot;/"/g;
    s/&#39;/'"'"'/g;
    s/&nbsp;/ /g;

    # Clean up excessive whitespace
    s/\n{3,}/\n\n/g;
    s/^\s+//;
    s/\s+$//;
  '
}

# ── Task Triage ──────────────────────────────────────────────────────────────
# Separates markdown into: open tasks, completed tasks, and non-task content.
# Preserves section headers so tasks stay grouped by category.

triage_tasks() {
  local markdown="$1"

  local open_tasks=""
  local done_tasks=""
  local other_content=""
  local current_heading=""
  local open_has_heading_printed=""
  local done_has_heading_printed=""

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Track section headings
    if [[ "$line" =~ ^#{1,4}[[:space:]] ]]; then
      current_heading="$line"
      open_has_heading_printed=""
      done_has_heading_printed=""
      continue
    fi

    # Checked item → completed
    if [[ "$line" =~ ^-[[:space:]]\[[xX]\] ]]; then
      if [[ -n "$current_heading" && -z "$done_has_heading_printed" ]]; then
        done_tasks+="${current_heading}"$'\n'
        done_has_heading_printed="1"
      fi
      done_tasks+="${line}"$'\n'
      continue
    fi

    # Unchecked item → open
    if [[ "$line" =~ ^-[[:space:]]\[[[:space:]]\] ]]; then
      if [[ -n "$current_heading" && -z "$open_has_heading_printed" ]]; then
        open_tasks+="${current_heading}"$'\n'
        open_has_heading_printed="1"
      fi
      open_tasks+="${line}"$'\n'
      continue
    fi

    # Non-checkbox content (descriptions, notes, etc.)
    if [[ -n "$line" ]]; then
      other_content+="${line}"$'\n'
    fi
  done <<< "$markdown"

  # Count
  local open_count=$(echo "$open_tasks" | grep -c '^\- \[ \]' || true)
  local done_count=$(echo "$done_tasks" | grep -c '^\- \[x\]\|^\- \[X\]' || true)

  # Output triaged markdown
  echo "## Open Tasks (${open_count})"
  echo ""
  if [[ -n "$open_tasks" ]]; then
    echo "$open_tasks"
  else
    echo "*No open tasks*"
  fi
  echo ""
  echo "## Completed Tasks (${done_count})"
  echo ""
  if [[ -n "$done_tasks" ]]; then
    echo "$done_tasks"
  else
    echo "*No completed tasks*"
  fi

  # Include non-checkbox content if any (notes, descriptions)
  if [[ -n "$other_content" ]]; then
    echo ""
    echo "## Notes"
    echo ""
    echo "$other_content"
  fi
}

# ── Sync a Single Note ───────────────────────────────────────────────────────

sync_note() {
  local note_name="$1"
  local note_folder="$2"
  local output_path="$3"
  local sync_state="$4"

  local note_key="${note_folder:+${note_folder}/}${note_name}"

  # Change detection
  if ! $FORCE_SYNC; then
    local mod_date
    mod_date=$(get_note_mod_date "$note_name" "$note_folder")

    if [[ "$mod_date" == "ERROR" ]]; then
      echo "WARNING: Could not get modification date for '${note_name}' — syncing anyway"
    else
      local last_synced
      last_synced=$(get_last_synced_mod "$note_key" "$sync_state")

      if [[ -n "$last_synced" && "$last_synced" == "$mod_date" ]]; then
        echo "SKIP: '${note_name}' unchanged since last sync (${mod_date})"
        echo "$sync_state"
        return 0
      fi

      echo "CHANGED: '${note_name}' modified at ${mod_date} (last sync: ${last_synced:-never})"
      # Update state with new mod date
      sync_state=$(set_synced_mod "$note_key" "$mod_date" "$sync_state")
    fi
  fi

  # Fetch note content
  local applescript
  if [[ -n "$note_folder" ]]; then
    applescript="
      tell application \"Notes\"
        try
          set targetFolder to folder \"${note_folder}\"
          set targetNote to first note of targetFolder whose name is \"${note_name}\"
          return body of targetNote
        on error
          return \"ERROR: Note '${note_name}' not found in folder '${note_folder}'\"
        end try
      end tell
    "
  else
    applescript="
      tell application \"Notes\"
        try
          set targetNote to first note whose name is \"${note_name}\"
          return body of targetNote
        on error
          return \"ERROR: Note '${note_name}' not found\"
        end try
      end tell
    "
  fi

  local raw_content
  raw_content=$(osascript -e "$applescript")

  if [[ "$raw_content" == ERROR:* ]]; then
    echo "$raw_content"
    echo "$sync_state"
    return 1
  fi

  # Convert and triage
  local markdown_content
  markdown_content=$(convert_to_markdown "$raw_content")

  local triaged_content
  triaged_content=$(triage_tasks "$markdown_content")

  # Write output
  local sync_timestamp
  sync_timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local open_count=$(echo "$triaged_content" | grep -c '^\- \[ \]' || true)
  local done_count=$(echo "$triaged_content" | grep -c '^\- \[x\]\|^\- \[X\]' || true)
  local total=$((open_count + done_count))

  cat > "$output_path" << HEREDOC
---
source: apple-notes
note_name: "${note_name}"
${note_folder:+note_folder: "${note_folder}"}
synced_at: ${sync_timestamp}
sync_method: osascript
tasks_open: ${open_count}
tasks_done: ${done_count}
tasks_total: ${total}
---

# ${note_name}

> Synced: ${sync_timestamp} | ${open_count} open, ${done_count} done

${triaged_content}
HEREDOC

  echo "Synced: '${note_name}' → $(basename "$output_path") (${open_count} open, ${done_count} done)"

  # Return updated state
  echo "$sync_state"
}

# ── Folder Mode: Sync All Notes in Folder ────────────────────────────────────

sync_folder() {
  local folder_name="$1"

  echo "Syncing all notes in folder: \"${folder_name}\"..."

  # Get list of notes in folder with modification dates
  local note_list
  note_list=$(osascript -e "
    tell application \"Notes\"
      try
        set targetFolder to folder \"${folder_name}\"
        set noteList to {}
        repeat with aNote in notes of targetFolder
          set noteTitle to name of aNote
          set end of noteList to noteTitle
        end repeat
        set AppleScript's text item delimiters to linefeed
        return noteList as text
      on error
        return \"ERROR: Folder '${folder_name}' not found\"
      end try
    end tell
  ")

  if [[ "$note_list" == ERROR:* ]]; then
    echo "$note_list"
    exit 1
  fi

  local sync_state
  sync_state=$(load_sync_state)
  local synced_count=0
  local skipped_count=0
  local files_changed=()

  while IFS= read -r note_title; do
    [[ -z "$note_title" ]] && continue

    local slug
    slug=$(slugify "$note_title")
    local out_path="${TASKS_DIR}/${slug}.md"

    local result
    result=$(sync_note "$note_title" "$folder_name" "$out_path" "$sync_state")

    # Last line of result is the updated state
    sync_state=$(echo "$result" | tail -1)

    if echo "$result" | grep -q "^SKIP:"; then
      ((skipped_count++))
    else
      ((synced_count++))
      files_changed+=("$out_path")
    fi
  done <<< "$note_list"

  save_sync_state "$sync_state"

  echo ""
  echo "Folder sync complete: ${synced_count} synced, ${skipped_count} unchanged"

  # Auto push if requested
  if $AUTO_PUSH && [[ ${#files_changed[@]} -gt 0 ]]; then
    auto_push_changes "${files_changed[@]}"
  elif $AUTO_PUSH; then
    echo "No changes to push."
  fi
}

# ── Auto Push ─────────────────────────────────────────────────────────────────

auto_push_changes() {
  local files=("$@")

  echo ""
  echo "Committing and pushing..."

  # Find the git repo root
  local repo_root=""
  if [[ -d "${HOME}/Personal_AI_Infrastructure/.git" ]]; then
    repo_root="${HOME}/Personal_AI_Infrastructure"
  elif git -C "$PAI_DIR" rev-parse --show-toplevel &>/dev/null; then
    repo_root=$(git -C "$PAI_DIR" rev-parse --show-toplevel)
  fi

  if [[ -n "$repo_root" ]]; then
    cd "$repo_root"
    git add "${files[@]}" "$SYNC_STATE_FILE"
    # Check if there are actual changes staged
    if git diff --cached --quiet; then
      echo "No changes to commit."
      return 0
    fi
    local sync_timestamp
    sync_timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    git commit -m "sync: update tasks from Apple Notes

Timestamp: ${sync_timestamp}
Files: ${#files[@]} updated"
    git push
    echo "Pushed to remote."
  else
    echo "WARNING: Could not find git repo. Files saved locally only."
  fi
}

# ── Main Execution ───────────────────────────────────────────────────────────

# Folder mode: sync all notes in a folder
if $FOLDER_MODE; then
  sync_folder "$NOTE_FOLDER"
  exit 0
fi

# Single note mode
echo "Syncing Apple Note: \"${NOTE_NAME}\"..."

SYNC_STATE=$(load_sync_state)
RESULT=$(sync_note "$NOTE_NAME" "$NOTE_FOLDER" "$OUTPUT_FILE" "$SYNC_STATE")

# Extract updated state (last line) and save
UPDATED_STATE=$(echo "$RESULT" | tail -1)
save_sync_state "$UPDATED_STATE"

# Check if it was skipped
if echo "$RESULT" | grep -q "^SKIP:"; then
  echo "$RESULT" | grep "^SKIP:"
  if $AUTO_PUSH; then
    echo "No changes to push."
  fi
  echo ""
  echo "Done. No changes detected."
  exit 0
fi

echo "$RESULT" | grep -v "^{" | head -5

if $AUTO_PUSH; then
  auto_push_changes "$OUTPUT_FILE"
fi

echo ""
echo "Done. Task list is now available to PAI sessions."
