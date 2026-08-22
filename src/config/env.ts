import "dotenv/config";
import { z } from "zod";

const envSchema = z.object({
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
  PORT: z.coerce.number().default(3000),
  API_PREFIX: z.string().default("/api/v1"),

  DATABASE_URL: z.string().min(1, "DATABASE_URL is required"),

  JWT_ACCESS_SECRET: z.string().min(16, "JWT_ACCESS_SECRET must be set and reasonably long"),
  JWT_REFRESH_SECRET: z.string().min(16, "JWT_REFRESH_SECRET must be set and reasonably long"),
  ACCESS_TOKEN_EXPIRES: z.string().default("15m"),
  REFRESH_TOKEN_EXPIRES: z.string().default("30d"),

  // Firebase Admin - used server-side to verify Firebase ID tokens minted
  // after the client signs in with Google via Firebase Auth.
  // FIREBASE_PRIVATE_KEY typically comes from a downloaded service-account
  // JSON; when set via a .env file its embedded "\n" sequences need to be
  // turned back into real newlines (handled in src/config/firebase.ts).
  FIREBASE_PROJECT_ID: z.string().optional().default(""),
  FIREBASE_CLIENT_EMAIL: z.string().optional().default(""),
  FIREBASE_PRIVATE_KEY: z.string().optional().default(""),

  CORS_ORIGIN: z.string().default("http://localhost:3000"),

  GEMINI_API_KEY: z.string().optional().default(""),
  GEMINI_MODEL: z.string().default("gemini-1.5-flash"),
  HUGGINGFACE_API_KEY: z.string().optional().default(""),
  HUGGINGFACE_MODEL: z.string().default("meta-llama/Meta-Llama-3-8B-Instruct"),
  DEFAULT_AI_PROVIDER: z.enum(["gemini", "huggingface"]).default("gemini"),

  AUTH_RATE_LIMIT_WINDOW_MS: z.coerce.number().default(900000),
  AUTH_RATE_LIMIT_MAX: z.coerce.number().default(10),
  GLOBAL_RATE_LIMIT_WINDOW_MS: z.coerce.number().default(60000),
  GLOBAL_RATE_LIMIT_MAX: z.coerce.number().default(120),

  LOG_LEVEL: z.string().default("info"),
});

// In test environments we allow a lighter-weight config so unit tests
// don't require a full production .env file.
const parsed = envSchema.safeParse(process.env);

if (!parsed.success) {
  // eslint-disable-next-line no-console
  console.error("Invalid environment configuration:", parsed.error.flatten().fieldErrors);
  throw new Error("Invalid environment configuration. Check your .env file against .env.example");
}

export const env = parsed.data;
export const isProduction = env.NODE_ENV === "production";
export const isTest = env.NODE_ENV === "test";
