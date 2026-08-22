import { env } from "../../config/env";
import { logger } from "../../config/logger";
import { AIGenerateOptions, AIGenerateResult, AIProvider, ProviderUnavailableError } from "./providers/AIProvider";
import { GeminiProvider } from "./providers/GeminiProvider";
import { HuggingFaceProvider } from "./providers/HuggingFaceProvider";

// The AI Router selects which configured provider actually handles a
// given request, and falls back to the next healthy provider if the
// preferred one fails. This is purely a RELIABILITY mechanism - it
// never rotates API keys/accounts to dodge a single provider's quota
// or terms of service (spec rule #14).
export class AIRouter {
  private providers: AIProvider[];

  constructor(providers: AIProvider[] = [new GeminiProvider(), new HuggingFaceProvider()]) {
    this.providers = providers;
  }

  private orderedCandidates(userPreference?: string): AIProvider[] {
    const configured = this.providers.filter((p) => p.isConfigured());

    // 1. Explicit user preference wins, if that provider is configured.
    const preferred = configured.find((p) => p.name === userPreference);

    // 2. Otherwise fall back to the server-wide default provider.
    const defaultProvider = configured.find((p) => p.name === env.DEFAULT_AI_PROVIDER);

    const ordered = [preferred, defaultProvider, ...configured].filter(
      (p): p is AIProvider => Boolean(p)
    );

    // De-duplicate while preserving priority order.
    const seen = new Set<string>();
    return ordered.filter((p) => (seen.has(p.name) ? false : (seen.add(p.name), true)));
  }

  async generate(
    prompt: string,
    userPreference?: string,
    options?: AIGenerateOptions
  ): Promise<AIGenerateResult> {
    const candidates = this.orderedCandidates(userPreference);

    if (candidates.length === 0) {
      throw new ProviderUnavailableError(
        "none",
        "No AI providers are currently configured on this server"
      );
    }

    let lastError: unknown;

    for (const provider of candidates) {
      try {
        return await provider.generate(prompt, options);
      } catch (err) {
        lastError = err;
        logger.warn(
          { provider: provider.name, err: (err as Error)?.message },
          "AI provider failed, trying next fallback"
        );
      }
    }

    throw lastError instanceof Error
      ? lastError
      : new ProviderUnavailableError("unknown", "All AI providers failed");
  }
}

export const aiRouter = new AIRouter();
