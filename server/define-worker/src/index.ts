/**
 * POST { "term": "context rot" } → { pos, beginner, builder, research, example, analogy }
 *
 * Drafts a three-level definition for AI-Cab's "Your own words". Keeps the Anthropic API key
 * on the server; the app only knows this URL.
 */
import Anthropic from "@anthropic-ai/sdk";

interface Env {
  ANTHROPIC_API_KEY: string;
}

const SYSTEM = `You write definitions for AI-Cab, an app that teaches AI vocabulary.
Return a definition at three depths:
- beginner: plain English, max 25 words, no jargon.
- builder: how an engineer meets it in practice, max 35 words.
- research: the precise technical idea, max 45 words.
Also give one everyday analogy and one example sentence that contains the term verbatim.
If the term is not an AI/ML/tech concept you can define accurately, say so in "beginner" and keep the rest brief. Never invent facts.`;

const SCHEMA = {
  type: "object",
  properties: {
    pos: { type: "string", enum: ["n.", "v.", "adj.", "adv."] },
    beginner: { type: "string" },
    builder: { type: "string" },
    research: { type: "string" },
    analogy: { type: "string" },
    example: { type: "string" },
  },
  required: ["pos", "beginner", "builder", "research", "analogy", "example"],
  additionalProperties: false,
} as const;

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method !== "POST") return json({ error: "POST only" }, 405);

    let term: string;
    try {
      const body = (await request.json()) as { term?: unknown };
      term = typeof body.term === "string" ? body.term.trim() : "";
    } catch {
      return json({ error: "Invalid JSON" }, 400);
    }
    if (!term || term.length > 80) return json({ error: "term must be 1-80 characters" }, 400);

    const client = new Anthropic({ apiKey: env.ANTHROPIC_API_KEY });
    try {
      const response = await client.beta.messages.create({
        model: "claude-opus-5-5",
        max_tokens: 2000,
        betas: ["server-side-fallback-2026-07-01"],
        fallbacks: "default",
        output_config: { effort: "low", format: { type: "json_schema", schema: SCHEMA } },
        system: SYSTEM,
        messages: [{ role: "user", content: `Term: ${term}` }],
      });
      if (response.stop_reason === "refusal") return json({ error: "Can't define that term" }, 422);
      const block = response.content.find((b) => b.type === "text");
      if (!block || block.type !== "text") return json({ error: "Empty response" }, 502);
      return json(JSON.parse(block.text));
    } catch (error) {
      if (error instanceof Anthropic.RateLimitError) return json({ error: "Busy, try again shortly" }, 429);
      if (error instanceof Anthropic.APIError) return json({ error: "Upstream error" }, 502);
      if (error instanceof SyntaxError) return json({ error: "Malformed draft" }, 502);
      throw error;
    }
  },
} satisfies ExportedHandler<Env>;
