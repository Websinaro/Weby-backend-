import { NextFunction, Request, Response } from "express";
import { ZodError } from "zod";
import { ApiError } from "../utils/ApiError";
import { sendError } from "../utils/ApiResponse";
import { logger } from "../config/logger";
import { isProduction } from "../config/env";

// Centralized error handler. Ensures we NEVER leak stack traces or
// internal details to the client in production, and that every error
// is logged with a safe, structured payload.
// eslint-disable-next-line @typescript-eslint/no-unused-vars
export function errorHandler(err: unknown, req: Request, res: Response, _next: NextFunction) {
  if (err instanceof ApiError) {
    logger.warn(
      { requestId: req.requestId, code: err.code, statusCode: err.statusCode },
      err.message
    );
    return sendError(res, err.statusCode, err.code, err.message, err.details);
  }

  if (err instanceof ZodError) {
    return sendError(res, 400, "VALIDATION_ERROR", "Invalid request data", err.flatten());
  }

  // Unknown/unexpected error - log full detail server-side, but return
  // only a generic, safe message to the client.
  logger.error({ requestId: req.requestId, err }, "Unhandled error");

  return sendError(
    res,
    500,
    "INTERNAL_ERROR",
    isProduction ? "Something went wrong. Please try again." : (err as Error)?.message ?? "Unknown error"
  );
}
