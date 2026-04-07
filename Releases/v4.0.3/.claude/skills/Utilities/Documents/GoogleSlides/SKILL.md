---
name: GoogleSlides
description: Read and extract content from Google Slides presentations — text extraction, formatting preservation, speaker notes, and structured export. USE WHEN google slides, read google slides, extract google slides, google presentation, gslides.
---

# Google Slides Reader

## Load Full PAI Context

**Before starting any task with this skill, load complete PAI context:**

`read ~/.claude/PAI/SKILL.md`

## When to Use This Sub-Skill

### Explicit Triggers
Route to this sub-skill when user requests contain:

**Reading Triggers:**
- "read google slides", "extract google slides"
- "what's in this google slides", "read this presentation"
- "get text from google slides", "google slides content"

**Analysis Triggers:**
- "analyze google slides", "summarize this presentation"
- "extract speaker notes from google slides"
- "google slides to markdown", "google slides to json"

### Contextual Triggers
Route to this sub-skill when:
- User provides a Google Slides URL (docs.google.com/presentation)
- User mentions "Google Slides" or "Google presentation"
- User provides a Google Slides presentation ID
- User wants to read a cloud-hosted presentation (not a .pptx file)

### Workflow Routing

**Text Extraction Workflow (Markdown):**
- "read google slides", "what's in this presentation"
- Default output: clean markdown with slide headings
- → Run `read.ts` with `--format markdown`

**Structured Extraction Workflow (JSON):**
- "extract structured data", "get formatting info"
- Outputs JSON with text, formatting, positions, and speaker notes
- → Run `read.ts` with `--format json`

**Speaker Notes Extraction:**
- "get speaker notes", "extract presenter notes"
- → Run `read.ts` with `--notes-only`

## Overview

This skill reads Google Slides presentations via the Google Slides API v1. It extracts text content, formatting, speaker notes, and structural information from any accessible presentation.

## Authentication

The tool requires a Google API credential. It checks these in order:

1. **`GOOGLE_API_KEY`** environment variable — works for presentations shared as "Anyone with the link can view"
2. **`GOOGLE_OAUTH_TOKEN`** environment variable — OAuth2 access token for private presentations
3. **`GOOGLE_SERVICE_ACCOUNT_KEY`** environment variable — path to a service account JSON key file

Set credentials in `~/.claude/.env`.

## Usage

```bash
# Read a presentation by URL (markdown output)
bun scripts/read.ts "https://docs.google.com/presentation/d/PRESENTATION_ID/edit"

# Read by presentation ID
bun scripts/read.ts PRESENTATION_ID

# JSON output with full formatting info
bun scripts/read.ts PRESENTATION_ID --format json

# Extract only speaker notes
bun scripts/read.ts PRESENTATION_ID --notes-only

# Save output to file
bun scripts/read.ts PRESENTATION_ID --format json --output slides.json
bun scripts/read.ts PRESENTATION_ID --format markdown --output slides.md
```

**Note:** All script paths are relative to this skill directory:
`~/.claude/skills/Utilities/Documents/GoogleSlides/`

## Output Formats

### Markdown Output (default)
```markdown
# Presentation Title

## Slide 1: Welcome
Welcome to our presentation.
- First bullet point
- Second bullet point

> **Speaker Notes:** Remember to introduce the team.

## Slide 2: Overview
...
```

### JSON Output
```json
{
  "title": "Presentation Title",
  "locale": "en",
  "slideWidth": 10.0,
  "slideHeight": 5.625,
  "slides": [
    {
      "index": 0,
      "objectId": "slide_id",
      "elements": [
        {
          "objectId": "element_id",
          "type": "SHAPE",
          "position": { "x": 1.5, "y": 0.5 },
          "size": { "width": 7.0, "height": 1.2 },
          "text": {
            "paragraphs": [
              {
                "text": "Welcome to our presentation",
                "bullet": false,
                "alignment": "CENTER",
                "style": {
                  "fontFamily": "Arial",
                  "fontSize": 24,
                  "bold": true,
                  "italic": false,
                  "foregroundColor": "#000000"
                }
              }
            ]
          }
        }
      ],
      "speakerNotes": "Remember to introduce the team."
    }
  ]
}
```

## Examples

**Example 1: Quick read of a shared presentation**
```
User: "Read this Google Slides deck: https://docs.google.com/presentation/d/abc123/edit"
-> Extracts presentation ID from URL
-> Fetches via Google Slides API
-> Outputs clean markdown with all slide content
```

**Example 2: Structured extraction for further processing**
```
User: "Extract all text and formatting from this Google Slides presentation as JSON"
-> Runs read.ts with --format json
-> Returns structured data with positions, fonts, colors
-> Can be used as input for PPTX creation or analysis
```

**Example 3: Speaker notes for a talk**
```
User: "Get the speaker notes from my presentation"
-> Runs read.ts with --notes-only
-> Returns just the speaker notes per slide
```

## Dependencies

- **Bun** runtime (already installed via PAI)
- **Google API Key** or OAuth token in `~/.claude/.env`
- No additional packages required (uses built-in fetch)
