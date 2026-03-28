# Paperwork Manager

A paperwork processing system for ScanSnap 2500 (or any scanner that outputs multi-page PDFs). Splits scanned PDFs into individual documents, classifies them using AI, tracks bills, and files everything to Google Drive.

## Quick Start

### 1. Install Dependencies

```bash
# macOS
brew install poppler jq

# Linux (Ubuntu/Debian)
sudo apt install poppler-utils jq
```

### 2. Install Google Drive for Desktop

Download from [Google Drive](https://www.google.com/drive/download/) and sign in. This creates a local sync folder (typically `~/Google Drive/My Drive/`).

### 3. Configure ScanSnap

Set your ScanSnap 2500 to save scanned PDFs to:
```
~/Google Drive/My Drive/Scans/Inbox
```

### 4. Edit Folder Mappings

Edit `config.json` to match your Google Drive folder structure:
```json
{
  "scan_folder": "~/Google Drive/My Drive/Scans/Inbox",
  "filing_folders": {
    "bills": "~/Google Drive/My Drive/Documents/Bills & Financial",
    "tax": "~/Google Drive/My Drive/Documents/Tax",
    ...
  }
}
```

### 5. Process Paperwork

In Claude Code, run:
```
/paperwork process ~/Google\ Drive/My\ Drive/Scans/Inbox/scan-2026-03-28.pdf
```

Or simply:
```
/paperwork process
```
to process all PDFs in the scan inbox.

## Components

| File | Purpose |
|------|--------|
| `SKILL.md` | Claude Code skill definition — the AI workflow |
| `config.json` | Folder mappings and configuration |
| `pdf-processor.sh` | Split PDFs and extract text per page |
| `bill-tracker.sh` | Track, pay, and file bills |
| `file-document.sh` | Copy documents to Google Drive folders |
| `merge-pages.sh` | Merge multi-page documents back together |

## Workflow

```
ScanSnap 2500
    │
    ▼
Google Drive/Scans/Inbox/  ← multi-page PDF lands here
    │
    ▼
/paperwork process
    │
    ├── Split PDF into pages (poppler)
    ├── Extract text from each page
    ├── AI classifies each page
    ├── Group multi-page documents
    ├── Bills → ask user → bill tracker
    └── File each document to correct folder
    │
    ▼
Google Drive/Documents/{category}/  ← filed documents

Later:
    /paperwork bills        ← see what's unpaid
    /paperwork pay <id>     ← mark as paid + file
```

## Bill Tracker

```bash
# List unpaid bills
./bill-tracker.sh list --unpaid

# Mark a bill as paid
./bill-tracker.sh pay abc12345

# File a paid bill
./bill-tracker.sh file abc12345 "~/Google Drive/My Drive/Documents/Bills & Financial"

# See all bills
./bill-tracker.sh list --all
```
