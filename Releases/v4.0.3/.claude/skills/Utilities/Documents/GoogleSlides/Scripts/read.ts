#!/usr/bin/env bun

/**
 * Google Slides Reader - Extract content from Google Slides presentations
 *
 * Reads presentations via Google Slides API v1 and outputs structured text
 * with formatting, positions, and speaker notes.
 *
 * Usage:
 *   bun read.ts <presentation-id-or-url> [--format json|markdown] [--notes-only] [--output file]
 *
 * Auth (checked in order):
 *   GOOGLE_API_KEY          - for public presentations
 *   GOOGLE_OAUTH_TOKEN      - OAuth2 access token for private presentations
 *   GOOGLE_SERVICE_ACCOUNT_KEY - path to service account JSON key file
 */

import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";

// ============================================================================
// Environment Loading
// ============================================================================

async function loadEnv(): Promise<void> {
  const paiDir = process.env.PAI_DIR || resolve(process.env.HOME!, ".claude");
  const envPath = resolve(paiDir, ".env");
  try {
    const envContent = await readFile(envPath, "utf-8");
    for (const line of envContent.split("\n")) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith("#")) continue;
      const eqIndex = trimmed.indexOf("=");
      if (eqIndex === -1) continue;
      const key = trimmed.slice(0, eqIndex).trim();
      let value = trimmed.slice(eqIndex + 1).trim();
      if (
        (value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))
      ) {
        value = value.slice(1, -1);
      }
      if (!process.env[key]) {
        process.env[key] = value;
      }
    }
  } catch {
    // .env not found — rely on shell env vars
  }
}

// ============================================================================
// Types
// ============================================================================

interface SlideElement {
  objectId: string;
  type: string;
  position: { x: number; y: number };
  size: { width: number; height: number };
  text: {
    paragraphs: ParagraphData[];
  } | null;
}

interface ParagraphData {
  text: string;
  bullet: boolean;
  level: number;
  alignment: string;
  style: {
    fontFamily: string;
    fontSize: number;
    bold: boolean;
    italic: boolean;
    underline: boolean;
    foregroundColor: string;
  };
}

interface SlideData {
  index: number;
  objectId: string;
  elements: SlideElement[];
  speakerNotes: string;
}

interface PresentationData {
  title: string;
  locale: string;
  slideWidth: number;
  slideHeight: number;
  slides: SlideData[];
}

interface CLIArgs {
  presentationId: string;
  format: "json" | "markdown";
  notesOnly: boolean;
  output: string | null;
}

// ============================================================================
// Google Slides API
// ============================================================================

const API_BASE = "https://slides.googleapis.com/v1/presentations";

function extractPresentationId(input: string): string {
  // Handle full URLs
  const urlPattern = /\/presentation\/d\/([a-zA-Z0-9_-]+)/;
  const match = input.match(urlPattern);
  if (match) return match[1];

  // Handle /edit, /view suffixes on bare IDs (shouldn't happen but be safe)
  const cleaned = input.replace(/\/(edit|view|pub|export).*$/, "");

  // If it looks like a presentation ID (alphanumeric, hyphens, underscores)
  if (/^[a-zA-Z0-9_-]+$/.test(cleaned)) return cleaned;

  throw new Error(
    `Cannot extract presentation ID from: ${input}\n` +
      `Provide a Google Slides URL or presentation ID.`
  );
}

async function getAuthHeaders(): Promise<Record<string, string>> {
  // 1. API Key — append to URL, no auth header needed
  if (process.env.GOOGLE_API_KEY) {
    return {};
  }

  // 2. OAuth2 access token
  if (process.env.GOOGLE_OAUTH_TOKEN) {
    return { Authorization: `Bearer ${process.env.GOOGLE_OAUTH_TOKEN}` };
  }

  // 3. Service account key file — exchange for access token
  if (process.env.GOOGLE_SERVICE_ACCOUNT_KEY) {
    const token = await getServiceAccountToken(
      process.env.GOOGLE_SERVICE_ACCOUNT_KEY
    );
    return { Authorization: `Bearer ${token}` };
  }

  throw new Error(
    "No Google API credentials found.\n" +
      "Set one of these in ~/.claude/.env:\n" +
      "  GOOGLE_API_KEY=...              (for public presentations)\n" +
      "  GOOGLE_OAUTH_TOKEN=...          (OAuth2 access token)\n" +
      "  GOOGLE_SERVICE_ACCOUNT_KEY=...  (path to service account JSON)"
  );
}

async function getServiceAccountToken(keyPath: string): Promise<string> {
  const keyFile = JSON.parse(await readFile(resolve(keyPath), "utf-8"));
  const now = Math.floor(Date.now() / 1000);

  // Build JWT
  const header = btoa(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const payload = btoa(
    JSON.stringify({
      iss: keyFile.client_email,
      scope: "https://www.googleapis.com/auth/presentations.readonly",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    })
  );

  // Sign with private key
  const signingKey = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(keyFile.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    signingKey,
    new TextEncoder().encode(`${header}.${payload}`)
  );

  const jwt = `${header}.${payload}.${base64urlEncode(signature)}`;

  // Exchange JWT for access token
  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  if (!tokenRes.ok) {
    throw new Error(
      `Service account token exchange failed: ${tokenRes.status} ${await tokenRes.text()}`
    );
  }

  const tokenData = (await tokenRes.json()) as { access_token: string };
  return tokenData.access_token;
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\n/g, "");
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

function base64urlEncode(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer);
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function fetchPresentation(presentationId: string): Promise<any> {
  const headers = await getAuthHeaders();
  let url = `${API_BASE}/${presentationId}`;

  if (process.env.GOOGLE_API_KEY) {
    url += `?key=${process.env.GOOGLE_API_KEY}`;
  }

  const res = await fetch(url, { headers });

  if (!res.ok) {
    const body = await res.text();
    if (res.status === 404) {
      throw new Error(
        `Presentation not found: ${presentationId}\n` +
          `Verify the ID and that the presentation is shared/accessible.`
      );
    }
    if (res.status === 403) {
      throw new Error(
        `Access denied to presentation: ${presentationId}\n` +
          `Ensure the presentation is shared and your credentials have access.`
      );
    }
    throw new Error(`Google Slides API error (${res.status}): ${body}`);
  }

  return res.json();
}

// ============================================================================
// Parsing
// ============================================================================

function emuToInches(emu: number | undefined): number {
  if (!emu) return 0;
  return Math.round((emu / 914400) * 100) / 100;
}

function rgbToHex(color: any): string {
  if (!color?.rgbColor) return "#000000";
  const r = Math.round((color.rgbColor.red || 0) * 255);
  const g = Math.round((color.rgbColor.green || 0) * 255);
  const b = Math.round((color.rgbColor.blue || 0) * 255);
  return `#${r.toString(16).padStart(2, "0")}${g.toString(16).padStart(2, "0")}${b.toString(16).padStart(2, "0")}`;
}

function parseTextStyle(style: any): ParagraphData["style"] {
  return {
    fontFamily: style?.fontFamily || "Arial",
    fontSize: style?.fontSize?.magnitude || 12,
    bold: style?.bold || false,
    italic: style?.italic || false,
    underline: style?.underline || false,
    foregroundColor: rgbToHex(style?.foregroundColor),
  };
}

function parseParagraph(paragraph: any): ParagraphData | null {
  const elements = paragraph.textElements || [];
  let text = "";
  let dominantStyle: any = null;

  for (const el of elements) {
    if (el.textRun) {
      text += el.textRun.content || "";
      if (!dominantStyle && el.textRun.style) {
        dominantStyle = el.textRun.style;
      }
    }
  }

  // Strip trailing newline (Slides API includes one per paragraph)
  text = text.replace(/\n$/, "");
  if (!text) return null;

  const pStyle = paragraph.paragraphStyle || {};
  const bullet = paragraph.bullet != null;
  const level = bullet ? (paragraph.bullet?.nestingLevel || 0) : 0;

  const alignment = pStyle.alignment || "START";
  const alignmentMap: Record<string, string> = {
    START: "LEFT",
    CENTER: "CENTER",
    END: "RIGHT",
    JUSTIFIED: "JUSTIFY",
  };

  return {
    text,
    bullet,
    level,
    alignment: alignmentMap[alignment] || "LEFT",
    style: parseTextStyle(dominantStyle || {}),
  };
}

function parseElement(element: any): SlideElement | null {
  const transform = element.transform || {};
  const size = element.size || {};

  const position = {
    x: emuToInches(transform.translateX),
    y: emuToInches(transform.translateY),
  };
  const dimensions = {
    width: emuToInches(size.width?.magnitude),
    height: emuToInches(size.height?.magnitude),
  };

  // Determine element type
  let type = "UNKNOWN";
  if (element.shape) type = "SHAPE";
  else if (element.table) type = "TABLE";
  else if (element.image) type = "IMAGE";
  else if (element.video) type = "VIDEO";
  else if (element.line) type = "LINE";
  else if (element.sheetsChart) type = "SHEETS_CHART";
  else if (element.wordArt) type = "WORD_ART";

  // Extract text content
  let textContent: SlideElement["text"] = null;

  if (element.shape?.text) {
    const paragraphs: ParagraphData[] = [];
    for (const p of element.shape.text.textElements || []) {
      // textElements at shape level are paragraphs wrapped in a different structure
      // The actual paragraphs are in shape.text.textElements with paragraphMarker
    }

    // Parse from the text body directly
    const textBody = element.shape.text;
    if (textBody.textElements) {
      let currentParagraph: { elements: any[]; marker: any } = {
        elements: [],
        marker: null,
      };
      const rawParagraphs: typeof currentParagraph[] = [];

      for (const te of textBody.textElements) {
        if (te.paragraphMarker) {
          if (currentParagraph.elements.length > 0) {
            rawParagraphs.push(currentParagraph);
          }
          currentParagraph = {
            elements: [],
            marker: te.paragraphMarker,
          };
        } else {
          currentParagraph.elements.push(te);
        }
      }
      if (currentParagraph.elements.length > 0) {
        rawParagraphs.push(currentParagraph);
      }

      for (const rp of rawParagraphs) {
        let text = "";
        let dominantStyle: any = null;

        for (const el of rp.elements) {
          if (el.textRun) {
            text += el.textRun.content || "";
            if (!dominantStyle && el.textRun.style) {
              dominantStyle = el.textRun.style;
            }
          }
        }

        text = text.replace(/\n$/, "");
        if (!text) continue;

        const pStyle = rp.marker?.style || {};
        const bullet = rp.marker?.bullet != null;
        const level = bullet ? (rp.marker?.bullet?.nestingLevel || 0) : 0;

        const alignment = pStyle.alignment || "START";
        const alignmentMap: Record<string, string> = {
          START: "LEFT",
          CENTER: "CENTER",
          END: "RIGHT",
          JUSTIFIED: "JUSTIFY",
        };

        paragraphs.push({
          text,
          bullet,
          level,
          alignment: alignmentMap[alignment] || "LEFT",
          style: parseTextStyle(dominantStyle || {}),
        });
      }

      if (paragraphs.length > 0) {
        textContent = { paragraphs };
      }
    }
  }

  // Also handle table text
  if (element.table) {
    const paragraphs: ParagraphData[] = [];
    for (const row of element.table.tableRows || []) {
      for (const cell of row.tableCells || []) {
        if (cell.text?.textElements) {
          let cellText = "";
          for (const te of cell.text.textElements) {
            if (te.textRun) cellText += te.textRun.content || "";
          }
          cellText = cellText.replace(/\n$/, "").trim();
          if (cellText) {
            paragraphs.push({
              text: cellText,
              bullet: false,
              level: 0,
              alignment: "LEFT",
              style: parseTextStyle({}),
            });
          }
        }
      }
    }
    if (paragraphs.length > 0) {
      textContent = { paragraphs };
    }
  }

  // Skip elements with no text content
  if (!textContent) return null;

  return {
    objectId: element.objectId || "",
    type,
    position,
    size: dimensions,
    text: textContent,
  };
}

function parseSpeakerNotes(slide: any): string {
  const notes = slide.slideProperties?.notesPage;
  if (!notes) return "";

  // Speaker notes are in the notes page's page elements
  for (const element of notes.pageElements || []) {
    if (element.shape?.shapeType === "TEXT_BOX" && element.shape?.text) {
      let text = "";
      for (const te of element.shape.text.textElements || []) {
        if (te.textRun) text += te.textRun.content || "";
      }
      text = text.trim();
      if (text) return text;
    }
    // Also check placeholder-based notes
    if (
      element.shape?.placeholder?.type === "BODY" &&
      element.shape?.text
    ) {
      let text = "";
      for (const te of element.shape.text.textElements || []) {
        if (te.textRun) text += te.textRun.content || "";
      }
      text = text.trim();
      if (text) return text;
    }
  }

  return "";
}

function parsePresentation(raw: any): PresentationData {
  const pageSize = raw.pageSize || {};
  const slides: SlideData[] = [];

  for (let i = 0; i < (raw.slides || []).length; i++) {
    const slide = raw.slides[i];
    const elements: SlideElement[] = [];

    for (const element of slide.pageElements || []) {
      const parsed = parseElement(element);
      if (parsed) elements.push(parsed);
    }

    // Sort elements by position (top-to-bottom, left-to-right)
    elements.sort((a, b) => {
      const yDiff = a.position.y - b.position.y;
      if (Math.abs(yDiff) > 0.3) return yDiff;
      return a.position.x - b.position.x;
    });

    slides.push({
      index: i,
      objectId: slide.objectId || "",
      elements,
      speakerNotes: parseSpeakerNotes(slide),
    });
  }

  return {
    title: raw.title || "Untitled Presentation",
    locale: raw.locale || "en",
    slideWidth: emuToInches(pageSize.width?.magnitude),
    slideHeight: emuToInches(pageSize.height?.magnitude),
    slides,
  };
}

// ============================================================================
// Output Formatting
// ============================================================================

function toMarkdown(data: PresentationData, notesOnly: boolean): string {
  const lines: string[] = [`# ${data.title}`, ""];

  for (const slide of data.slides) {
    if (notesOnly) {
      if (slide.speakerNotes) {
        lines.push(`## Slide ${slide.index + 1}`);
        lines.push(slide.speakerNotes);
        lines.push("");
      }
      continue;
    }

    // Build slide heading from first element or use index
    let heading = `Slide ${slide.index + 1}`;
    if (slide.elements.length > 0) {
      const firstText = slide.elements[0].text?.paragraphs[0]?.text;
      if (firstText && firstText.length <= 80) {
        heading = `Slide ${slide.index + 1}: ${firstText}`;
      }
    }
    lines.push(`## ${heading}`);
    lines.push("");

    // Skip first element text if used in heading
    const startIdx =
      slide.elements.length > 0 &&
      heading.includes(slide.elements[0].text?.paragraphs[0]?.text || "\0")
        ? 0
        : -1;

    for (let e = 0; e < slide.elements.length; e++) {
      const el = slide.elements[e];
      if (!el.text) continue;

      for (const p of el.text.paragraphs) {
        // Skip if this exact text was already used in heading (first element, first paragraph)
        if (e === 0 && p === el.text.paragraphs[0] && startIdx === 0) continue;

        const indent = p.bullet ? "  ".repeat(p.level) : "";
        const prefix = p.bullet ? "- " : "";
        let text = p.text;

        if (p.style.bold && !p.bullet) text = `**${text}**`;
        if (p.style.italic) text = `*${text}*`;

        lines.push(`${indent}${prefix}${text}`);
      }
      lines.push("");
    }

    if (slide.speakerNotes) {
      lines.push(`> **Speaker Notes:** ${slide.speakerNotes}`);
      lines.push("");
    }
  }

  return lines.join("\n");
}

function toJSON(data: PresentationData): string {
  return JSON.stringify(data, null, 2);
}

// ============================================================================
// CLI
// ============================================================================

function parseArgs(): CLIArgs {
  const args = process.argv.slice(2);

  if (args.length === 0 || args.includes("--help") || args.includes("-h")) {
    console.log(`Usage: bun read.ts <presentation-id-or-url> [options]

Options:
  --format <json|markdown>  Output format (default: markdown)
  --notes-only              Extract only speaker notes
  --output <file>           Write output to file instead of stdout
  -h, --help                Show this help`);
    process.exit(0);
  }

  const result: CLIArgs = {
    presentationId: "",
    format: "markdown",
    notesOnly: false,
    output: null,
  };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === "--format" && args[i + 1]) {
      const fmt = args[++i];
      if (fmt !== "json" && fmt !== "markdown") {
        console.error(`Invalid format: ${fmt}. Use 'json' or 'markdown'.`);
        process.exit(1);
      }
      result.format = fmt;
    } else if (arg === "--notes-only") {
      result.notesOnly = true;
    } else if (arg === "--output" && args[i + 1]) {
      result.output = args[++i];
    } else if (!arg.startsWith("--") && !result.presentationId) {
      result.presentationId = arg;
    }
  }

  if (!result.presentationId) {
    console.error("Error: Presentation ID or URL is required.");
    process.exit(1);
  }

  return result;
}

async function main() {
  await loadEnv();
  const args = parseArgs();

  const presentationId = extractPresentationId(args.presentationId);
  console.error(`Fetching presentation: ${presentationId}`);

  const raw = await fetchPresentation(presentationId);
  const data = parsePresentation(raw);

  console.error(
    `Extracted ${data.slides.length} slides from "${data.title}"`
  );

  const output =
    args.format === "json"
      ? toJSON(data)
      : toMarkdown(data, args.notesOnly);

  if (args.output) {
    await writeFile(args.output, output, "utf-8");
    console.error(`Output written to: ${args.output}`);
  } else {
    console.log(output);
  }
}

main().catch((err) => {
  console.error(`Error: ${err.message}`);
  process.exit(1);
});
