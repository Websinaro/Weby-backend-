import pino from "pino";
import { env, isProduction } from "./env";

// Structured logger. In production this emits JSON lines suitable for
// ingestion by any log aggregator. Locally it pretty-prints for readability.
//
// IMPORTANT: never pass secrets (passwords, tokens, API keys) to this logger.
// The redact list below is a defense-in-depth safety net, not a substitute
// for keeping secrets out of log calls in the first place.
export const logger = pino({
  level: env.LOG_LEVEL,
  redact: {
    paths: [
      "req.headers.authorization",
      "req.headers.cookie",
      "password",
      "*.password",
      "passwordHash",
      "*.passwordHash",
      "accessToken",
      "refreshToken",
      "*.accessToken",
      "*.refreshToken",
      "token",
      "*.token",
      "apiKey",
      "*.apiKey",
      "googleIdToken",
    ],
    censor: "[REDACTED]",
  },
  transport: isProduction
    ? undefined
    : {
        target: "pino-pretty",
        options: { colorize: true, translateTime: "HH:MM:ss", ignore: "pid,hostname" },
      },
});
