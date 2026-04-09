import type { ActionContext } from "../../lib/types.v2";

interface Input {
  thread: string;
  instruction: string;
  triage_state?: string;
  sender?: string;
  subject?: string;
  tone?: string;
  [key: string]: unknown;
}

interface Output {
  draft_reply: string;
  draft_subject: string;
  notes: string;
  [key: string]: unknown;
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

export default {
  async execute(input: Input, ctx: ActionContext): Promise<Output> {
    const { thread, instruction, triage_state, sender, subject, tone, ...upstream } = input;

    if (!thread) throw new Error("Missing required input: thread");
    if (!instruction) throw new Error("Missing required input: instruction");

    const llm = ctx.capabilities.llm;
    if (!llm) throw new Error("LLM capability required");

    const parts: string[] = [];
    if (subject) parts.push(`Subject: ${subject}`);
    if (sender) parts.push(`From: ${sender}`);
    if (triage_state) parts.push(`Triage State: ${triage_state}`);
    if (tone) parts.push(`Tone: ${tone}`);
    parts.push(`\nInstruction: ${instruction}`);
    parts.push(`\n---\n\nThread:\n${thread}`);

    const prompt = parts.join("\n");

    const result = await llm(prompt, {
      system: SYSTEM_PROMPT,
      tier: "standard",
      json: true,
      maxTokens: 2048,
    });

    const parsed = result.json as Output;

    return {
      ...upstream,
      draft_reply: parsed.draft_reply,
      draft_subject: parsed.draft_subject || `Re: ${subject || ""}`.trim(),
      notes: parsed.notes || "",
    };
  },
};
