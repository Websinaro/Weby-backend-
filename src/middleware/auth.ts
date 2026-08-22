import { NextFunction, Request, Response } from "express";
import { ApiError } from "../utils/ApiError";
import { verifyAccessToken } from "../utils/tokens";

// Extracts and verifies the Bearer access token, then attaches the
// authenticated user id to the request. Every downstream handler must
// derive "who is making this request" from req.userId - never from a
// client-supplied body/query field (spec rule: never trust frontend user IDs).
export function authenticate(req: Request, _res: Response, next: NextFunction) {
  const header = req.headers.authorization;

  if (!header || !header.startsWith("Bearer ")) {
    return next(ApiError.unauthorized("Missing or malformed Authorization header"));
  }

  const token = header.slice("Bearer ".length).trim();

  try {
    const payload = verifyAccessToken(token);
    req.userId = payload.sub;
    return next();
  } catch {
    return next(ApiError.unauthorized("Invalid or expired access token", "TOKEN_INVALID"));
  }
}
