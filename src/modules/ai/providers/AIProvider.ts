// Common contract every AI backend must implement. The rest of the app
// (router, service, controller) only ever talks to this interface, so
// adding a new provider means writing one new class - nothing else changes.
export interface AIChatMessage {
  role: "user" | "assistant" | "system";
  content: string;
}

export interface AIGenerateOptions {
  model?: string;
  history?: AIChatMessage[];
}

export interface AIGenerateResult {
  text: string;
  provider: string;
  model: string;
}

export class ProviderUnavailableError extends Error {
  constructor(public providerName: string, message: string) {
    super(message);
    this.name = "ProviderUnavailableError";
  }
}

export interface AIProvider {
  readonly name: string;
  /** Whether this provider has the credentials/config needed to run right now. */
  isConfigured(): boolean;
  generate(prompt: string, options?: AIGenerateOptions): Promise<AIGenerateResult>;
}
