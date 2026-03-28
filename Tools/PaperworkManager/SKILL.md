# /paperwork — Paperwork Management Skill

Process scanned multi-page PDFs from a ScanSnap 2500, triage documents interactively, track bills, and file everything to Google Drive. Learns vendor/sender patterns to auto-suggest filing over time.

## Trigger

When the user says `/paperwork` or asks to process scanned documents, manage bills, triage paperwork, or file documents.

## Subcommands

- `/paperwork triage` — Check scan inbox for new PDFs and triage them interactively
- `/paperwork bills` — Show unpaid bills
- `/paperwork paid <bill_id>` — Mark a bill as paid and file it
- `/paperwork config` — Show or edit folder mappings
- `/paperwork rules` — Show learned vendor/sender filing rules

## The Core Workflow

The user scans up to 50 pages at once on their ScanSnap 2500. The PDF lands in the scan inbox on Google Drive. At some point, they invoke `/paperwork triage` and we walk through every document together.

### Step 1: Check the Inbox

Look for new PDFs in the scan folder:
```
~/Library/CloudStorage/GoogleDrive-james.s.orsillo@gmail.com/My Drive/Scans/Inbox/
```

If no PDFs found, tell the user the inbox is empty.

### Step 2: Split the PDF

For each PDF in the inbox, run:
```bash
bash ~/Personal_AI_Infrastructure/Tools/PaperworkManager/pdf-processor.sh "<pdf_path>" "<working_dir>"
```

This splits into individual page PDFs and extracts text from each page.

### Step 3: Read and Classify Each Page

For each page, read the extracted text file and determine:

1. **Vendor/Sender** — Who sent this? (e.g., "Con Edison", "Chase Bank", "IRS", "Dr. Smith")
2. **Document type** — What kind of document is it?
3. **Is it a bill that needs payment?**
4. **Does it span multiple pages?** (look for "page 1 of 3", continuation headers, same sender on consecutive pages)

**Check vendor rules first.** Read `~/.paperwork-manager/vendor-rules.json` — if the vendor has been seen before, use the learned category as the suggestion.

### Step 4: Group Multi-Page Documents

If consecutive pages belong to the same document, merge them:
```bash
bash ~/Personal_AI_Infrastructure/Tools/PaperworkManager/merge-pages.sh "output.pdf" "page-001.pdf" "page-002.pdf"
```

### Step 5: Triage Each Document Interactively

For each document, present to the user:

> **Document: [page X]**
> **Vendor/Sender:** Con Edison
> **Type:** Utility bill
> **Amount due:** $142.37
> **Due date:** April 15, 2026
>
> **Suggested action:** File to Bills/Unpaid, add to bill tracker
> **Suggested category:** `bills_unpaid`
> *(Based on: [vendor rule / AI classification])*

Then ask:
- "Does this need to be paid?" (if it's a bill)
- "Where should I file this?" — suggest the category, let user confirm or override

**Filing categories:**

| Category | What goes here |
|----------|---------------|
| `bills_unpaid` | Bills waiting to be paid |
| `bills_paid` | Bills after payment |
| `receipts` | Receipts from paid bills, purchase receipts |
| `tax_documents` | W-2s, 1099s, tax notices, property tax bills |
| `bank_statements` | Bank and credit card statements |
| `financial_statements` | Investment statements, retirement accounts, net worth docs |
| `medical` | EOBs, lab results, prescriptions, medical bills |
| `insurance` | Policy docs, claims, coverage letters |
| `real_estate` | Mortgage docs, property records, HOA, deeds |
| `employment` | Pay stubs, offer letters, employment verification |
| `correspondence` | Government letters, legal notices, personal letters |
| `warranties` | Product warranties, manuals, registration |
| `misc` | Anything that doesn't fit above |

### Step 6: Execute Filing

For bills that need payment:
```bash
bash ~/Personal_AI_Infrastructure/Tools/PaperworkManager/bill-tracker.sh add "<vendor> - <description>" "<amount>" "<due_date>" "<source_pdf>"
```
Then file to `bills_unpaid`.

For all documents:
```bash
bash ~/Personal_AI_Infrastructure/Tools/PaperworkManager/file-document.sh "<source_pdf>" "<target_folder>" "<YYYY-MM-DD_vendor_description.pdf>"
```

Folder mappings are in:
```
~/Personal_AI_Infrastructure/Tools/PaperworkManager/config.json
```

### Step 7: Learn the Vendor Rule

After the user approves a filing, save the vendor → category mapping to `~/.paperwork-manager/vendor-rules.json`:

```json
{
  "rules": [
    {
      "vendor": "Con Edison",
      "keywords": ["con edison", "coned"],
      "category": "bills_unpaid",
      "is_bill": true,
      "last_seen": "2026-03-28",
      "times_seen": 1
    }
  ]
}
```

Next time this vendor appears, auto-suggest the same category. Increment `times_seen` and update `last_seen`.

### Step 8: Move Original to Processed

After all pages are triaged and filed:
```bash
mv "<original_pdf>" "<processed_folder>/"
```

### Step 9: Summary

Present:
- Total pages processed
- Documents identified (vendor + type)
- Bills added to tracker (with amounts and due dates)
- Files saved to which folders
- New vendor rules learned

## Bill Lifecycle

### 1. Bill arrives in scan → triage adds it to tracker + files to Bills/Unpaid
### 2. User pays the bill offline
### 3. User runs `/paperwork paid <bill_id>`

When marking a bill as paid:
```bash
bash ~/Personal_AI_Infrastructure/Tools/PaperworkManager/bill-tracker.sh pay <bill_id>
```

Then move the PDF from Bills/Unpaid to Bills/Paid:
```bash
bash ~/Personal_AI_Infrastructure/Tools/PaperworkManager/bill-tracker.sh file <bill_id> "<bills_paid_folder>"
```

Also ask: "Do you have a receipt or confirmation for this payment?" If yes, file that to the Receipts folder.

### List unpaid bills
```bash
bash ~/Personal_AI_Infrastructure/Tools/PaperworkManager/bill-tracker.sh list --unpaid
```

### List all bills
```bash
bash ~/Personal_AI_Infrastructure/Tools/PaperworkManager/bill-tracker.sh list --all
```

## Vendor Rules System

The system learns from every triage session. Rules are stored in `~/.paperwork-manager/vendor-rules.json`.

- **First time seeing a vendor:** AI classifies, asks user to confirm, saves rule
- **Subsequent times:** Auto-suggests based on saved rule, user can still override
- **Override updates the rule:** If user changes the category, the rule is updated

To view rules:
```bash
cat ~/.paperwork-manager/vendor-rules.json | jq '.rules[] | "\(.vendor) → \(.category) (seen \(.times_seen)x)"'
```

## Configuration

Edit `~/Personal_AI_Infrastructure/Tools/PaperworkManager/config.json` to customize:

- `scan_folder` — Where ScanSnap saves PDFs
- `processed_folder` — Where originals go after triage
- `drives` — Personal and work Google Drive paths
- `filing_folders` — Category → folder mappings
- `vendor_rules_path` — Learned vendor rules database
- `bill_tracker_path` — Bills JSON database

## Dependencies

- `poppler-utils` — PDF splitting and text extraction
- `jq` — JSON processing
- Google Drive for Desktop — Local folder sync

Install on macOS:
```bash
brew install poppler jq
```
