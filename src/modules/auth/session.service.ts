import { Request } from "express";
import { prisma } from "../../database/prisma";
import { env } from "../../config/env";
import { hashToken, msFromExpiryString, signRefreshToken } from "../../utils/tokens";

// Sessions represent one issued refresh token / logged-in device.
// The raw refresh token is NEVER persisted - only its SHA-256 hash,
// so a database leak alone can't be used to mint new access tokens.
export async function createSession(userId: string, req: Request) {
  const expiresAt = new Date(Date.now() + msFromExpiryString(env.REFRESH_TOKEN_EXPIRES));

  // Create the session row first (without a real token bound yet) so we
  // can embed its id inside the refresh token payload, then update the hash.
  const session = await prisma.session.create({
    data: {
      userId,
      tokenHash: "pending",
      expiresAt,
      userAgent: req.headers["user-agent"]?.toString().slice(0, 512),
      ipAddress: req.ip,
    },
  });

  const refreshToken = signRefreshToken(userId, session.id);

  await prisma.session.update({
    where: { id: session.id },
    data: { tokenHash: hashToken(refreshToken) },
  });

  return { refreshToken, sessionId: session.id, expiresAt };
}

export async function findValidSession(sessionId: string, refreshToken: string) {
  const session = await prisma.session.findUnique({ where: { id: sessionId } });

  if (!session) return null;
  if (session.revokedAt) return null;
  if (session.expiresAt.getTime() < Date.now()) return null;
  if (session.tokenHash !== hashToken(refreshToken)) return null;

  return session;
}

export async function revokeSession(sessionId: string) {
  await prisma.session.updateMany({
    where: { id: sessionId, revokedAt: null },
    data: { revokedAt: new Date() },
  });
}

export async function revokeAllSessions(userId: string) {
  await prisma.session.updateMany({
    where: { userId, revokedAt: null },
    data: { revokedAt: new Date() },
  });
}

// Refresh-token rotation: the old session is revoked and a brand new
// session/refresh token pair is issued. If a revoked token is ever
// replayed, this makes the reuse detectable (the lookup will fail
// because tokenHash no longer matches the caller's stale token, and the
// session is already marked revoked).
export async function rotateSession(oldSessionId: string, userId: string, req: Request) {
  await revokeSession(oldSessionId);
  return createSession(userId, req);
}
