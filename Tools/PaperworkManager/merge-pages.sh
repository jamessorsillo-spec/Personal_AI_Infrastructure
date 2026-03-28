#!/usr/bin/env bash
# merge-pages.sh — Merge multiple PDF pages back into a single document
# Usage: ./merge-pages.sh <output.pdf> <page1.pdf> <page2.pdf> ...
#
# Useful when a single document spans multiple scanned pages.

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: merge-pages.sh <output.pdf> <page1.pdf> [page2.pdf ...]" >&2
  exit 1
fi

OUTPUT="$1"
shift

# Check dependency
if ! command -v pdfunite &>/dev/null; then
  echo "ERROR: 'pdfunite' not found. Install poppler-utils." >&2
  exit 1
fi

pdfunite "$@" "$OUTPUT"
echo "Merged $# page(s) → $OUTPUT"
