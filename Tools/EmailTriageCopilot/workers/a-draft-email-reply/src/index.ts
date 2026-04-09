/**
 * Cloudflare Worker — A_DRAFT_EMAIL_REPLY
 *
 * HTTP endpoint for drafting email replies with tone control.
 *
 * POST /          — Draft a reply (auth required)
 * GET  /health    — Health check (public)
 *
 * Secrets: AUTH_TOKEN, ANTHROPIC_API_KEY
 */

interface Env {
  AUTH_TOKEN: string;
  ANTHROPIC_API_KEY: string;
}

interface DraftRequest {
  thread: string;
  instruction: string;
  triage_state?: string;
  sender?: string;
  subject?: string;
  tone?: string;
}

interface DraftResult {
  draft_reply: string;
  draft_subject: string;
  notes: string;
}

const SYSTEM_PROMPT = `You are an email reply drafter. You produce concise, professional, direct email replies.

## Rules

- Be concise. Say what needs to be said and stop.
- Professional and direct tone by default. Adjust if a tone override is given.
- Do not over-commit or make promises beyond what the instruction specifies.
- Do not invent facts. If key information is missing, note it explicitly.
- Do not imply approvals that were not given.
- Preserve the sender's name/context appropriately.
- Match the formality level of the original thread.
- No fluff, no filler, no unnecessary pleasantries beyond a brief greeting.

## Tone Modifiers

If a tone is specified, adjust accordingly:
- "warmer" — add warmth, empathy, softer language
- "firmer" — more assertive, clear boundaries, less hedging
- "shorter" — cut to minimum viable reply
- "formal" — full business formality
- "casual" — relaxed, friendly

## Output Format

Respond with valid JSON:
{
  "draft_reply": "The full email reply text, ready to send",
  "draft_subject": "Re: original subject (or new subject if needed)",
  "notes": "Any flags about missing info, risks, or things the user should verify before sending. Empty string if none."
}`;

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
): Promise<DraftResult> {
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

  return JSON.parse(text) as DraftResult;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    // Health check — public
    if (url.pathname === "/health" && request.method === "GET") {
      return new Response(
        JSON.stringify({
          status: "ok",
          action: "A_DRAFT_EMAIL_REPLY",
          version: "1.0.0",
        }),
        { headers: { "Content-Type": "application/json" } }
      );
    }

    // All other routes require auth
    if (!validateAuth(request, env)) return unauthorized();

    // POST / — Draft a reply
    if (request.method === "POST" && (url.pathname === "/" || url.pathname === "")) {
      const start = Date.now();

      try {
        const body = (await request.json()) as DraftRequest;

        if (!body.thread) {
          return new Response(
            JSON.stringify({ error: "Missing required field: thread" }),
            { status: 400, headers: { "Content-Type": "application/json" } }
          );
        }
        if (!body.instruction) {
          return new Response(
            JSON.stringify({ error: "Missing required field: instruction" }),
            { status: 400, headers: { "Content-Type": "application/json" } }
          );
        }

        const parts: string[] = [];
        if (body.subject) parts.push(`Subject: ${body.subject}`);
        if (body.sender) parts.push(`From: ${body.sender}`);
        if (body.triage_state) parts.push(`Triage State: ${body.triage_state}`);
        if (body.tone) parts.push(`Tone: ${body.tone}`);
        parts.push(`\nInstruction: ${body.instruction}`);
        parts.push(`\n---\n\nThread:\n${body.thread}`);

        const prompt = parts.join("\n");
        const result = await callAnthropic(prompt, env.ANTHROPIC_API_KEY);
        const duration = Date.now() - start;

        return new Response(
          JSON.stringify({
            success: true,
            action: "A_DRAFT_EMAIL_REPLY",
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
            action: "A_DRAFT_EMAIL_REPLY",
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
