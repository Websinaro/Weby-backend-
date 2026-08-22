import { env } from "../../../config/env";
import { logger } from "../../../config/logger";
import {
  AIGenerateOptions,
  AIGenerateResult,
  AIProvider,
  ProviderUnavailableError,
} from "./AIProvider";

// Talks to Google's Generative Language API (Gemini) directly over
// HTTPS using fetch, so no extra SDK dependency is required. The API
// key is read from the server environment only - it is never sent to
// or accepted from the client.
export class GeminiProvider implements AIProvider {
  readonly name = "gemini";

  isConfigured(): boolean {
    return Boolean(env.GEMINI_API_KEY);
  }

  async generate(prompt: string, options: AIGenerateOptions = {}): Promise<AIGenerateResult> {
    if (!this.isConfigured()) {
      throw new ProviderUnavailableError(this.name, "Gemini API key is not configured");
    }

    const model = options.model ?? env.GEMINI_MODEL;
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${env.GEMINI_API_KEY}`;

    const contents = [
      ...(options.history ?? []).map((m) => ({
        role: m.role === "assistant" ? "model" : "user",
        parts: [{ text: m.content }],
      })),
      { role: "user", parts: [{ text: prompt }] },
    ];

    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ contents }),
    });

    if (!response.ok) {
      const body = await response.text().catch(() => "");
      logger.warn({ provider: this.name, status: response.status }, "Gemini request failed");
      throw new ProviderUnavailableError(
        this.name,
        `Gemini request failed with status ${response.status}: ${body.slice(0, 300)}`
      );
    }

    const data = (await response.json()) as any;
    const text: string | undefined = data?.candidates?.[0]?.content?.parts?.[0]?.text;

    if (!text) {
      throw new ProviderUnavailableError(this.name, "Gemini returned an empty response");
    }

    return { text, provider: this.name, model };
  }
}
