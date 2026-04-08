#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# Apple Notes → PAI Task Sync
# ═══════════════════════════════════════════════════════════════════════════════
#
# Exports a specific Apple Notes note to a markdown file that PAI can read
# across both local terminal and web sessions (via git).
#
# USAGE:
#   ./apple-notes-sync.sh                          # Uses default note name
#   ./apple-notes-sync.sh "My Task List"           # Specify note name
#   ./apple-notes-sync.sh --note "My Task List"    # Explicit flag
#   ./apple-notes-sync.sh --folder "Work"          # Specify folder
#   ./apple-notes-sync.sh --push                   # Auto git commit+push after sync
#   ./apple-notes-sync.sh --list                   # List all notes (for discovery)
#
# REQUIREMENTS:
#   - macOS (uses osascript/AppleScript)
#   - Apple Notes app with the target note
#
# OUTPUT:
#   ~/.claude/MEMORY/TASKS/master-tasks.md
#
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────

PAI_DIR="${PAI_DIR:-$HOME/.claude}"
TASKS_DIR="${PAI_DIR}/MEMORY/TASKS"
OUTPUT_FILE="${TASKS_DIR}/master-tasks.md"
DEFAULT_NOTE_NAME="Master Task List"
NOTE_NAME=""
NOTE_FOLDER=""
AUTO_PUSH=false
LIST_MODE=false

# ── Argument Parsing ──────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --note)
      NOTE_NAME="$2"
      shift 2
      ;;
    --folder)
      NOTE_FOLDER="$2"
      shift 2
      ;;
    --push)
      AUTO_PUSH=true
      shift
      ;;
    --list)
      LIST_MODE=true
      shift
      ;;
    --help|-h)
      echo "Usage: apple-notes-sync.sh [NOTE_NAME] [--note NAME] [--folder FOLDER] [--push] [--list]"
      echo ""
      echo "Options:"
      echo "  NOTE_NAME        Name of the Apple Note to sync (positional)"
      echo "  --note NAME      Name of the Apple Note to sync (flag)"
      echo "  --folder FOLDER  Apple Notes folder to search in"
      echo "  --push           Auto git commit and push after sync"
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

# ── List Mode ─────────────────────────────────────────────────────────────────

if $LIST_MODE; then
  echo "Listing Apple Notes..."
  osascript -e '
    tell application "Notes"
      set noteList to {}
      repeat with aNote in notes
        set noteTitle to name of aNote
        set noteFolder to name of container of aNote
        set end of noteList to noteFolder & " / " & noteTitle
      end repeat
      set AppleScript'\''s text item delimiters to linefeed
      return noteList as text
    end tell
  '
  exit 0
fi

# ── Export Note ───────────────────────────────────────────────────────────────

echo "Syncing Apple Note: \"${NOTE_NAME}\"..."

# Build the AppleScript based on whether folder is specified
if [[ -n "$NOTE_FOLDER" ]]; then
  APPLESCRIPT="
    tell application \"Notes\"
      try
        set targetFolder to folder \"${NOTE_FOLDER}\"
        set targetNote to first note of targetFolder whose name is \"${NOTE_NAME}\"
        return body of targetNote
      on error
        return \"ERROR: Note '${NOTE_NAME}' not found in folder '${NOTE_FOLDER}'\"
      end try
    end tell
  "
else
  APPLESCRIPT="
    tell application \"Notes\"
      try
        set targetNote to first note whose name is \"${NOTE_NAME}\"
        return body of targetNote
      on error
        return \"ERROR: Note '${NOTE_NAME}' not found\"
      end try
    end tell
  "
fi

RAW_CONTENT=$(osascript -e "$APPLESCRIPT")

# Check for errors
if [[ "$RAW_CONTENT" == ERROR:* ]]; then
  echo "$RAW_CONTENT"
  echo ""
  echo "Available notes:"
  "$0" --list | head -20
  exit 1
fi

# ── Convert HTML to Markdown ─────────────────────────────────────────────────
# Apple Notes returns HTML. We convert common patterns to markdown.

convert_to_markdown() {
  local content="$1"

  # Use perl for robust HTML→Markdown conversion
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

MARKDOWN_CONTENT=$(convert_to_markdown "$RAW_CONTENT")

# ── Write Output File ────────────────────────────────────────────────────────

mkdir -p "$TASKS_DIR"

SYNC_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
SYNC_SOURCE="apple-notes"
SYNC_NOTE_NAME="$NOTE_NAME"

cat > "$OUTPUT_FILE" << HEREDOC
---
source: ${SYNC_SOURCE}
note_name: "${SYNC_NOTE_NAME}"
synced_at: ${SYNC_TIMESTAMP}
sync_method: osascript
---

# Master Task List

> Synced from Apple Notes: "${NOTE_NAME}" on ${SYNC_TIMESTAMP}

${MARKDOWN_CONTENT}
HEREDOC

echo "Synced to: ${OUTPUT_FILE}"
echo "Content: $(wc -l < "$OUTPUT_FILE") lines, $(wc -c < "$OUTPUT_FILE") bytes"

# ── Auto Push ─────────────────────────────────────────────────────────────────

if $AUTO_PUSH; then
  echo ""
  echo "Committing and pushing..."

  # Find the git repo root (look for PAI repo)
  REPO_ROOT=""
  if [[ -d "${HOME}/Personal_AI_Infrastructure/.git" ]]; then
    REPO_ROOT="${HOME}/Personal_AI_Infrastructure"
  elif git -C "$PAI_DIR" rev-parse --show-toplevel &>/dev/null; then
    REPO_ROOT=$(git -C "$PAI_DIR" rev-parse --show-toplevel)
  fi

  if [[ -n "$REPO_ROOT" ]]; then
    cd "$REPO_ROOT"
    git add "$OUTPUT_FILE"
    git commit -m "sync: update master tasks from Apple Notes

Synced from: ${NOTE_NAME}
Timestamp: ${SYNC_TIMESTAMP}"
    git push
    echo "Pushed to remote."
  else
    echo "WARNING: Could not find git repo. File saved locally only."
    echo "Manually commit and push to make available in web sessions."
  fi
fi

echo ""
echo "Done. Task list is now available to PAI sessions."
