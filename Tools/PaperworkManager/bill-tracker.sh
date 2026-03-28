#!/usr/bin/env bash
# bill-tracker.sh — Manage a JSON-based bill tracking list
# Usage:
#   ./bill-tracker.sh add <description> <amount> <due_date> <source_pdf>
#   ./bill-tracker.sh list [--unpaid | --paid | --all]
#   ./bill-tracker.sh pay <bill_id>
#   ./bill-tracker.sh detail <bill_id>
#
# Bills file: ~/.paperwork-manager/bills.json

set -euo pipefail

BILLS_DIR="$HOME/.paperwork-manager"
BILLS_FILE="$BILLS_DIR/bills.json"

mkdir -p "$BILLS_DIR"

# Initialize bills file if it doesn't exist
if [[ ! -f "$BILLS_FILE" ]]; then
  echo '{"bills": []}' > "$BILLS_FILE"
fi

# Check for jq
if ! command -v jq &>/dev/null; then
  echo "ERROR: 'jq' not found. Install it:" >&2
  echo "  macOS:  brew install jq" >&2
  echo "  Linux:  sudo apt install jq" >&2
  exit 1
fi

ACTION="${1:-help}"
shift || true

case "$ACTION" in
  add)
    DESCRIPTION="${1:?Usage: bill-tracker.sh add <description> <amount> <due_date> <source_pdf>}"
    AMOUNT="${2:?Missing amount}"
    DUE_DATE="${3:?Missing due_date (YYYY-MM-DD)}"
    SOURCE_PDF="${4:?Missing source_pdf path}"

    BILL_ID=$(date +%s%N | shasum -a 256 | head -c 8)
    ADDED_DATE=$(date -Iseconds)

    jq --arg id "$BILL_ID" \
       --arg desc "$DESCRIPTION" \
       --arg amt "$AMOUNT" \
       --arg due "$DUE_DATE" \
       --arg src "$SOURCE_PDF" \
       --arg added "$ADDED_DATE" \
       '.bills += [{
         "id": $id,
         "description": $desc,
         "amount": $amt,
         "due_date": $due,
         "source_pdf": $src,
         "added_date": $added,
         "status": "unpaid",
         "paid_date": null,
         "filed_to": null
       }]' "$BILLS_FILE" > "$BILLS_FILE.tmp" && mv "$BILLS_FILE.tmp" "$BILLS_FILE"

    echo "Bill added: $DESCRIPTION (\$$AMOUNT due $DUE_DATE) [ID: $BILL_ID]"
    ;;

  list)
    FILTER="${1:---unpaid}"
    case "$FILTER" in
      --unpaid)
        jq -r '.bills[] | select(.status == "unpaid") | "[\(.id)] \(.description) — $\(.amount) due \(.due_date)"' "$BILLS_FILE"
        ;;
      --paid)
        jq -r '.bills[] | select(.status == "paid") | "[\(.id)] \(.description) — $\(.amount) paid \(.paid_date)"' "$BILLS_FILE"
        ;;
      --all)
        jq -r '.bills[] | "[\(.id)] [\(.status)] \(.description) — $\(.amount) due \(.due_date)"' "$BILLS_FILE"
        ;;
    esac
    ;;

  pay)
    BILL_ID="${1:?Usage: bill-tracker.sh pay <bill_id>}"
    PAID_DATE=$(date -Iseconds)

    # Check bill exists
    EXISTS=$(jq -r --arg id "$BILL_ID" '.bills[] | select(.id == $id) | .id' "$BILLS_FILE")
    if [[ -z "$EXISTS" ]]; then
      echo "ERROR: Bill ID '$BILL_ID' not found" >&2
      exit 1
    fi

    jq --arg id "$BILL_ID" --arg pd "$PAID_DATE" \
       '(.bills[] | select(.id == $id)) |= . + {"status": "paid", "paid_date": $pd}' \
       "$BILLS_FILE" > "$BILLS_FILE.tmp" && mv "$BILLS_FILE.tmp" "$BILLS_FILE"

    echo "Bill $BILL_ID marked as paid on $PAID_DATE"
    ;;

  file)
    BILL_ID="${1:?Usage: bill-tracker.sh file <bill_id> <destination_folder>}"
    DEST_FOLDER="${2:?Missing destination folder}"

    BILL=$(jq -r --arg id "$BILL_ID" '.bills[] | select(.id == $id)' "$BILLS_FILE")
    if [[ -z "$BILL" ]]; then
      echo "ERROR: Bill ID '$BILL_ID' not found" >&2
      exit 1
    fi

    SOURCE_PDF=$(echo "$BILL" | jq -r '.source_pdf')

    mkdir -p "$DEST_FOLDER"
    if [[ -f "$SOURCE_PDF" ]]; then
      cp "$SOURCE_PDF" "$DEST_FOLDER/"
      FILED_NAME=$(basename "$SOURCE_PDF")

      jq --arg id "$BILL_ID" --arg dest "$DEST_FOLDER/$FILED_NAME" \
         '(.bills[] | select(.id == $id)) |= . + {"filed_to": $dest}' \
         "$BILLS_FILE" > "$BILLS_FILE.tmp" && mv "$BILLS_FILE.tmp" "$BILLS_FILE"

      echo "Filed $SOURCE_PDF → $DEST_FOLDER/$FILED_NAME"
    else
      echo "ERROR: Source PDF not found: $SOURCE_PDF" >&2
      exit 1
    fi
    ;;

  detail)
    BILL_ID="${1:?Usage: bill-tracker.sh detail <bill_id>}"
    jq --arg id "$BILL_ID" '.bills[] | select(.id == $id)' "$BILLS_FILE"
    ;;

  help|*)
    echo "bill-tracker.sh — Manage scanned bill payments"
    echo ""
    echo "Commands:"
    echo "  add <description> <amount> <due_date> <source_pdf>  Add a new bill"
    echo "  list [--unpaid | --paid | --all]                    List bills"
    echo "  pay <bill_id>                                       Mark bill as paid"
    echo "  file <bill_id> <destination_folder>                 File bill PDF to folder"
    echo "  detail <bill_id>                                    Show bill details"
    ;;
esac
