#!/usr/bin/env bash
# file-document.sh — File a document PDF to a target Google Drive folder
# Usage: ./file-document.sh <source_pdf> <target_folder> [filename]
#
# If filename is not provided, uses the original filename.
# Creates the target folder if it doesn't exist.

set -euo pipefail

SOURCE_PDF="${1:?Usage: file-document.sh <source_pdf> <target_folder> [filename]}"
TARGET_FOLDER="${2:?Missing target folder}"
FILENAME="${3:-$(basename "$SOURCE_PDF")}"

# Expand tilde
TARGET_FOLDER="${TARGET_FOLDER/#\~/$HOME}"

if [[ ! -f "$SOURCE_PDF" ]]; then
  echo "ERROR: Source file not found: $SOURCE_PDF" >&2
  exit 1
fi

mkdir -p "$TARGET_FOLDER"
cp "$SOURCE_PDF" "$TARGET_FOLDER/$FILENAME"
echo "Filed: $SOURCE_PDF → $TARGET_FOLDER/$FILENAME"
