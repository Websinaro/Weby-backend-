import rateLimit from "express-rate-limit";
import { env } from "../config/env";
import { sendError } from "../utils/ApiResponse";

// Stricter limiter for authentication endpoints (register/login/refresh)
// to slow down credential-stuffing and brute-force attempts.
export const authRateLimiter = rateLimit({
  windowMs: env.AUTH_RATE_LIMIT_WINDOW_MS,
  max: env.AUTH_RATE_LIMIT_MAX,
  standardHeaders: true,
  legacyHeaders: false,
  handler: (_req, res) => {
    sendError(res, 429, "RATE_LIMITED", "Too many attempts. Please try again later.");
  },
});

// General-purpose limiter applied to the whole API.
export const globalRateLimiter = rateLimit({
  windowMs: env.GLOBAL_RATE_LIMIT_WINDOW_MS,
  max: env.GLOBAL_RATE_LIMIT_MAX,
  standardHeaders: true,
  legacyHeaders: false,
  handler: (_req, res) => {
    sendError(res, 429, "RATE_LIMITED", "Too many requests. Please slow down.");
  },
});
