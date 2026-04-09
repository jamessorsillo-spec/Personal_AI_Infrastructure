/**
 * Cloudflare Worker — A_TRIAGE_EMAIL
 *
 * HTTP endpoint for email triage using the GTD framework.
 * Accepts email thread content, returns classification + prepared artifacts.
 *
 * POST /          — Triage an email thread (auth required)
 * GET  /health    — Health check (public)
 *
 * Secrets: AUTH_TOKEN, ANTHROPIC_API_KEY
 */

interface Env {
  AUTH_TOKEN: string;
  ANTHROPIC_API_KEY: string;
}

interface TriageRequest {
  thread: string;
  sender?: string;
  subject?: string;
  context?: string;
}

interface TriageResult {
  triage_state: string;
  why_it_matters: string[];
  recommended_action: string;
  prepared_output: Record<string, unknown>;
  risk_flags: string[];
  commands: string[];
}

const SYSTEM_PROMPT = `You are an email triage copilot using a Getting Things Done (GTD) framework.

Your job: read the email thread, classify it, recommend one next action, and prepare the artifact.

## Classification States

Assign exactly ONE state:

- DO-NOW — Reply or act now; response is straightforward
- TASK — Requires work, research, preparation, or coordination
- WAITING-FOR — Someone else owes a response; delegated; needs follow-up reminder
- REFERENCE — Useful information, no current action
- ARCHIVE — No action, no meaningful future value
- REVIEW-REQUIRED — Sensitive, ambiguous, risky, or high consequence

## REVIEW-REQUIRED Triggers

Classify as REVIEW-REQUIRED when the email involves:
- Legal matters, finance approvals, pricing or commercial commitments
- Investor communication, HR or personnel matters
- Security, compliance, or regulatory issues
- Sensitive customer escalations
- Emotionally charged communication
- Ambiguity about what is being asked
- Any situation where the wrong response could create material risk

## Workflow

Step 1: Understand the thread — extract sender, participants, what they want, whether a response is owed, decisions/commitments/follow-ups, project context, sensitivity level.

Step 2: Classify — assign exactly one triage state.

Step 3: Recommend one next action — draft reply, create task, create waiting-for follow-up, label as reference, archive, snooze, or hold for review.

Step 4: Prepare the artifact:
- DO-NOW: draft a concise reply
- TASK: task proposal (title, project/workstream, next action, due date if implied, source summary)
- WAITING-FOR: follow-up proposal (who owns next step, what we're waiting on, suggested follow-up date, reason)
- REFERENCE: proposed label/folder treatment
- ARCHIVE: propose archive
- REVIEW-REQUIRED: summarize issue, risk, and decision required

## Output Format

Respond with valid JSON matching this structure:
{
  "triage_state": "DO-NOW | TASK | WAITING-FOR | REFERENCE | ARCHIVE | REVIEW-REQUIRED",
  "why_it_matters": ["bullet 1", "bullet 2", "bullet 3"],
  "recommended_action": "one clear action statement",
  "prepared_output": {
    // For DO-NOW: { "draft_reply": "..." }
    // For TASK: { "title": "...", "project": "...", "next_action": "...", "due_date": "...", "source_summary": "..." }
    // For WAITING-FOR: { "owner": "...", "waiting_on": "...", "follow_up_date": "...", "reason": "..." }
    // For REFERENCE: { "label": "...", "folder": "...", "note": "..." }
    // For ARCHIVE: { "reason": "..." }
    // For REVIEW-REQUIRED: { "issue": "...", "risk": "...", "decision_required": "..." }
  },
  "risk_flags": ["only include if relevant, otherwise empty array"],
  "commands": ["reply", "archive", "make task", "waiting for [person]", "snooze until Friday"]
}

## Rules

- Be concise, direct, executive-ready
- Preserve commitments — never let actionable work disappear
- Prefer task creation over leaving work trapped in inbox
- Prefer waiting-for tracking when someone else owes a response
- Prefer reference over archive when future context may matter
- Draft replies: concise, professional, direct. Do not over-commit. Do not invent facts.
- Task proposals: action-oriented titles, actual next action (not vague topics)
- 1-3 bullets max for why_it_matters
- 3-5 command options the user can type
- If the email is trivial, keep everything extremely short`;

function unauthorized(): Response {
  return new Response(JSON.stringify({ error: "Unauthorized" }), {
    status: 401,
    headers: { "Content-Type": "application/json" },
  });
}

function validateAuth(request: Request, env: Env): boolean {
  const auth = request.headers.get("Authorization");
  if (!auth) return false;
  const token = auth.replace("Bearer ", "");
  return token === env.AUTH_TOKEN;
}

async function callAnthropic(
  prompt: string,
  apiKey: string
): Promise<TriageResult> {
  const response = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: "claude-sonnet-4-20250514",
      max_tokens: 2048,
      system: SYSTEM_PROMPT,
      messages: [{ role: "user", content: prompt }],
    }),
  });

  if (!response.ok) {
    const err = await response.text();
    throw new Error(`Anthropic API error ${response.status}: ${err}`);
  }

  const data = (await response.json()) as {
    content: Array<{ type: string; text: string }>;
  };
  const text = data.content
    .filter((c) => c.type === "text")
    .map((c) => c.text)
    .join("");

  return JSON.parse(text) as TriageResult;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    // Health check — public
    if (url.pathname === "/health" && request.method === "GET") {
      return new Response(
        JSON.stringify({
          status: "ok",
          action: "A_TRIAGE_EMAIL",
          version: "1.0.0",
        }),
        { headers: { "Content-Type": "application/json" } }
      );
    }

    // All other routes require auth
    if (!validateAuth(request, env)) return unauthorized();

    // POST / — Triage an email
    if (request.method === "POST" && (url.pathname === "/" || url.pathname === "")) {
      const start = Date.now();

      try {
        const body = (await request.json()) as TriageRequest;

        if (!body.thread) {
          return new Response(
            JSON.stringify({ error: "Missing required field: thread" }),
            { status: 400, headers: { "Content-Type": "application/json" } }
          );
        }

        const parts: string[] = [];
        if (body.subject) parts.push(`Subject: ${body.subject}`);
        if (body.sender) parts.push(`From: ${body.sender}`);
        if (body.context) parts.push(`Context: ${body.context}`);
        parts.push(`\n---\n\n${body.thread}`);

        const prompt = parts.join("\n");
        const result = await callAnthropic(prompt, env.ANTHROPIC_API_KEY);
        const duration = Date.now() - start;

        return new Response(
          JSON.stringify({
            success: true,
            action: "A_TRIAGE_EMAIL",
            duration_ms: duration,
            output: result,
          }),
          { headers: { "Content-Type": "application/json" } }
        );
      } catch (err) {
        const duration = Date.now() - start;
        return new Response(
          JSON.stringify({
            success: false,
            action: "A_TRIAGE_EMAIL",
            duration_ms: duration,
            error: err instanceof Error ? err.message : String(err),
          }),
          { status: 500, headers: { "Content-Type": "application/json" } }
        );
      }
    }

    return new Response(JSON.stringify({ error: "Not found" }), {
      status: 404,
      headers: { "Content-Type": "application/json" },
    });
  },
};
