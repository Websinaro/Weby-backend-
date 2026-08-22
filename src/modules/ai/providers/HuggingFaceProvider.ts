import { env } from "../../../config/env";
import { logger } from "../../../config/logger";
import {
  AIGenerateOptions,
  AIGenerateResult,
  AIProvider,
  ProviderUnavailableError,
} from "./AIProvider";

// Talks to the Hugging Face Inference API. Used as a fallback provider
// when Gemini is unavailable, misconfigured, or unhealthy, or when the
// user's preference explicitly selects it.
export class HuggingFaceProvider implements AIProvider {
  readonly name = "huggingface";

  isConfigured(): boolean {
    return Boolean(env.HUGGINGFACE_API_KEY);
  }

  async generate(prompt: string, options: AIGenerateOptions = {}): Promise<AIGenerateResult> {
    if (!this.isConfigured()) {
      throw new ProviderUnavailableError(this.name, "Hugging Face API key is not configured");
    }

    const model = options.model ?? env.HUGGINGFACE_MODEL;
    const url = `https://api-inference.huggingface.co/models/${model}`;

    // Fold any conversation history into a single prompt, since the
    // basic Inference API text-generation task takes plain text input.
    const historyText = (options.history ?? [])
      .map((m) => `${m.role}: ${m.content}`)
      .join("\n");
    const fullPrompt = historyText ? `${historyText}\nuser: ${prompt}\nassistant:` : prompt;

    const response = await fetch(url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${env.HUGGINGFACE_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        inputs: fullPrompt,
        parameters: { max_new_tokens: 512, return_full_text: false },
      }),
    });

    if (!response.ok) {
      const body = await response.text().catch(() => "");
      logger.warn({ provider: this.name, status: response.status }, "Hugging Face request failed");
      throw new ProviderUnavailableError(
        this.name,
        `Hugging Face request failed with status ${response.status}: ${body.slice(0, 300)}`
      );
    }

    const data = (await response.json()) as any;
    const text: string | undefined = Array.isArray(data)
      ? data[0]?.generated_text
      : data?.generated_text;

    if (!text) {
      throw new ProviderUnavailableError(this.name, "Hugging Face returned an empty response");
    }

    return { text, provider: this.name, model };
  }
}
