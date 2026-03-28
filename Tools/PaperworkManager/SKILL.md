# /paperwork — Paperwork Management Skill

Process scanned multi-page PDFs from a ScanSnap scanner, classify each page, track bills, and file documents to Google Drive.

## Trigger

When the user says `/paperwork` or asks to process scanned documents, manage bills, or file paperwork.

## Subcommands

- `/paperwork process [path]` — Process a scanned PDF (split, classify, file)
- `/paperwork bills` — Show unpaid bills
- `/paperwork pay <bill_id>` — Mark a bill as paid and file it
- `/paperwork config` — Show or edit folder mappings
- `/paperwork status` — Show processing summary

## Workflow: Process a Scanned PDF

When processing a PDF, follow these steps exactly:

### Step 1: Split the PDF

Run the PDF processor to split and extract text:

```bash
bash ~/Personal_AI_Infrastructure/Tools/PaperworkManager/pdf-processor.sh "<pdf_path>" "<working_dir>"
```

This creates individual page PDFs and text files in the working directory.

### Step 2: Classify Each Page

For each extracted page, read the text file and classify the document into one of these categories:

| Category | Description | Examples |
|----------|-------------|----------|
| `bills` | Something that requires payment | Utility bills, credit card statements, invoices |
| `tax` | Tax-related documents | W-2s, 1099s, tax notices, property tax |
| `medical` | Medical records or bills | EOBs, lab results, prescriptions |
| `insurance` | Insurance documents | Policy docs, claims, coverage letters |
| `receipts` | Proof of purchase | Store receipts, online order confirmations |
| `personal` | Personal documents | Letters, cards, personal correspondence |
| `correspondence` | Official correspondence | Government letters, legal notices, bank letters |
| `warranties` | Product documentation | Warranties, manuals, registration cards |
| `misc` | Anything else | Flyers, misc papers |

For each page, determine:
1. **Category** — Which folder it belongs in
2. **Is it a bill?** — Does it require payment?
3. **Description** — Brief summary (e.g., "Electric bill - March 2026")
4. **Multi-page?** — Does this document span multiple pages? (look for continuation cues)

### Step 3: Group Multi-Page Documents

If consecutive pages belong to the same document (e.g., a 3-page bank statement), merge them:

```bash
bash ~/Personal_AI_Infrastructure/Tools/PaperworkManager/merge-pages.sh "output.pdf" "page-001.pdf" "page-002.pdf" "page-003.pdf"
```

### Step 4: Handle Bills

For each document classified as a bill:

1. **Ask the user**: "This looks like a bill: [description]. Amount: $X. Does this need to be paid?"
2. If YES, add to the bill tracker:
   ```bash
   bash ~/Personal_AI_Infrastructure/Tools/PaperworkManager/bill-tracker.sh add "<description>" "<amount>" "<due_date>" "<source_pdf>"
   ```
3. If NO (already paid or not applicable), proceed to filing.

### Step 5: File Documents

File each document to its mapped Google Drive folder:

```bash
bash ~/Personal_AI_Infrastructure/Tools/PaperworkManager/file-document.sh "<source_pdf>" "<target_folder>" "<descriptive_filename.pdf>"
```

Use descriptive filenames: `YYYY-MM-DD_description.pdf` (e.g., `2026-03-15_electric-bill.pdf`)

The folder mappings are in:
```
~/Personal_AI_Infrastructure/Tools/PaperworkManager/config.json
```

### Step 6: Move Original to Processed

After all pages are classified and filed, move the original scan:

```bash
mv "<original_pdf>" "<processed_folder>/"
```

### Step 7: Summary

Present a summary:
- Total pages processed
- Documents identified (with categories)
- Bills added to tracker
- Files saved to which folders

## Workflow: Manage Bills

### List unpaid bills
```bash
bash ~/Personal_AI_Infrastructure/Tools/PaperworkManager/bill-tracker.sh list --unpaid
```

### Mark a bill as paid
```bash
bash ~/Personal_AI_Infrastructure/Tools/PaperworkManager/bill-tracker.sh pay <bill_id>
```

Then file the paid bill:
```bash
bash ~/Personal_AI_Infrastructure/Tools/PaperworkManager/bill-tracker.sh file <bill_id> "<bills_folder>"
```

### Show all bills
```bash
bash ~/Personal_AI_Infrastructure/Tools/PaperworkManager/bill-tracker.sh list --all
```

## Configuration

Edit `~/Personal_AI_Infrastructure/Tools/PaperworkManager/config.json` to customize:

- `scan_folder` — Where ScanSnap saves PDFs (Google Drive sync folder)
- `processed_folder` — Where originals go after processing
- `filing_folders` — Category → Google Drive folder mappings
- `bill_tracker_path` — Location of the bills JSON database

## Dependencies

- `poppler-utils` — PDF splitting and text extraction (pdfseparate, pdfunite, pdftotext, pdfinfo)
- `jq` — JSON processing for bill tracker
- Google Drive for Desktop — Sync folders to local filesystem

Install:
```bash
# macOS
brew install poppler jq

# Linux
sudo apt install poppler-utils jq
```
