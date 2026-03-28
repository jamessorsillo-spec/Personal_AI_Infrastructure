#!/usr/bin/env bash
# pdf-processor.sh — Split a multi-page PDF into individual pages and extract text
# Dependencies: poppler-utils (pdfinfo, pdfseparate, pdftotext)
#
# Usage: ./pdf-processor.sh <input.pdf> [output_dir]
# Output: Creates one PDF + one TXT per page in output_dir

set -euo pipefail

INPUT_PDF="$1"
OUTPUT_DIR="${2:-$(mktemp -d /tmp/paperwork-XXXXXX)}"

if [[ ! -f "$INPUT_PDF" ]]; then
  echo "ERROR: File not found: $INPUT_PDF" >&2
  exit 1
fi

# Check dependencies
for cmd in pdfinfo pdfseparate pdftotext; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: '$cmd' not found. Install poppler-utils:" >&2
    echo "  macOS:  brew install poppler" >&2
    echo "  Linux:  sudo apt install poppler-utils" >&2
    exit 1
  fi
done

mkdir -p "$OUTPUT_DIR"

# Get page count
PAGE_COUNT=$(pdfinfo "$INPUT_PDF" | grep -i "^Pages:" | awk '{print $2}')
echo "PDF has $PAGE_COUNT page(s)"

# Split into individual pages
echo "Splitting PDF into individual pages..."
pdfseparate "$INPUT_PDF" "$OUTPUT_DIR/page-%03d.pdf"

# Extract text from each page
echo "Extracting text from each page..."
for page_pdf in "$OUTPUT_DIR"/page-*.pdf; do
  page_txt="${page_pdf%.pdf}.txt"
  pdftotext -layout "$page_pdf" "$page_txt"
done

# Output manifest as JSON
echo "{"
echo "  \"source\": \"$INPUT_PDF\","
echo "  \"page_count\": $PAGE_COUNT,"
echo "  \"output_dir\": \"$OUTPUT_DIR\","
echo "  \"pages\": ["
first=true
for i in $(seq -w 1 "$PAGE_COUNT"); do
  padded=$(printf "%03d" "$((10#$i))")
  if [ "$first" = true ]; then
    first=false
  else
    echo ","
  fi
  printf "    {\"page\": %d, \"pdf\": \"%s/page-%s.pdf\", \"text\": \"%s/page-%s.txt\"}" "$((10#$i))" "$OUTPUT_DIR" "$padded" "$OUTPUT_DIR" "$padded"
done
echo ""
echo "  ]"
echo "}"
