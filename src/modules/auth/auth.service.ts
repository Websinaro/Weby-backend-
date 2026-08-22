import { Request } from "express";
import { prisma } from "../../database/prisma";
import { ApiError } from "../../utils/ApiError";
import { hashPassword, verifyPassword } from "../../utils/password";
import { signAccessToken, verifyRefreshToken } from "../../utils/tokens";
import { createSession, findValidSession, revokeAllSessions, revokeSession, rotateSession } from "./session.service";
import { verifyGoogleIdToken } from "./google.service";
import { LoginInput, RegisterInput } from "./auth.schema";

function publicUser(user: {
  id: string;
  email: string;
  name: string;
  avatarUrl: string | null;
  authProvider: string;
  emailVerified: boolean;
}) {
  return {
    id: user.id,
    email: user.email,
    name: user.name,
    avatarUrl: user.avatarUrl,
    authProvider: user.authProvider,
    emailVerified: user.emailVerified,
  };
}

async function issueTokens(userId: string, req: Request) {
  const accessToken = signAccessToken(userId);
  const { refreshToken } = await createSession(userId, req);
  return { accessToken, refreshToken };
}

export async function register(input: RegisterInput, req: Request) {
  const existing = await prisma.user.findUnique({ where: { email: input.email } });
  if (existing) {
    // Generic message to avoid confirming which specific field collided
    // beyond "an account already exists" - still informative enough for
    // legitimate users while limiting enumeration detail.
    throw ApiError.conflict("An account with this email already exists", "EMAIL_IN_USE");
  }

  const passwordHash = await hashPassword(input.password);

  const user = await prisma.user.create({
    data: {
      email: input.email,
      name: input.name,
      passwordHash,
      authProvider: "EMAIL",
      emailVerified: false,
    },
  });

  await prisma.preference.create({ data: { userId: user.id } });

  const tokens = await issueTokens(user.id, req);
  return { user: publicUser(user), ...tokens };
}

export async function login(input: LoginInput, req: Request) {
  const user = await prisma.user.findUnique({ where: { email: input.email } });

  // Use a single generic error for "no such user" and "wrong password"
  // to avoid account enumeration via response differences.
  const genericError = () => ApiError.unauthorized("Invalid email or password", "INVALID_CREDENTIALS");

  if (!user || !user.passwordHash) throw genericError();

  const valid = await verifyPassword(user.passwordHash, input.password);
  if (!valid) throw genericError();

  await prisma.user.update({ where: { id: user.id }, data: { lastLoginAt: new Date() } });

  const tokens = await issueTokens(user.id, req);
  return { user: publicUser(user), ...tokens };
}

export async function loginWithGoogle(idToken: string, req: Request) {
  const identity = await verifyGoogleIdToken(idToken);

  let user = await prisma.user.findUnique({ where: { googleId: identity.googleId } });

  if (!user) {
    // Look for an existing email/password account with the same email.
    // We only link accounts when Google has verified the email address
    // itself - never merge purely because the email string matches.
    const existingByEmail = await prisma.user.findUnique({ where: { email: identity.email } });

    if (existingByEmail && identity.emailVerified) {
      user = await prisma.user.update({
        where: { id: existingByEmail.id },
        data: {
          googleId: identity.googleId,
          emailVerified: true,
          avatarUrl: existingByEmail.avatarUrl ?? identity.avatarUrl,
          lastLoginAt: new Date(),
        },
      });
    } else if (existingByEmail && !identity.emailVerified) {
      throw ApiError.conflict(
        "An account with this email already exists and could not be safely linked",
        "EMAIL_IN_USE"
      );
    } else {
      user = await prisma.user.create({
        data: {
          email: identity.email,
          name: identity.name,
          avatarUrl: identity.avatarUrl,
          googleId: identity.googleId,
          authProvider: "GOOGLE",
          emailVerified: identity.emailVerified,
          lastLoginAt: new Date(),
        },
      });
      await prisma.preference.create({ data: { userId: user.id } });
    }
  } else {
    user = await prisma.user.update({
      where: { id: user.id },
      data: { lastLoginAt: new Date() },
    });
  }

  const tokens = await issueTokens(user.id, req);
  return { user: publicUser(user), ...tokens };
}

export async function refresh(refreshToken: string, req: Request) {
  let payload;
  try {
    payload = verifyRefreshToken(refreshToken);
  } catch {
    throw ApiError.unauthorized("Invalid or expired refresh token", "REFRESH_TOKEN_INVALID");
  }

  const session = await findValidSession(payload.sid, refreshToken);
  if (!session) {
    throw ApiError.unauthorized("Session has been revoked or expired", "SESSION_INVALID");
  }

  const user = await prisma.user.findUnique({ where: { id: payload.sub } });
  if (!user) throw ApiError.unauthorized("User not found", "SESSION_INVALID");

  // Rotate: revoke the used refresh token and issue a new session so a
  // stolen/replayed refresh token can only ever be used once.
  const { refreshToken: newRefreshToken } = await rotateSession(session.id, user.id, req);
  const accessToken = signAccessToken(user.id);

  return { user: publicUser(user), accessToken, refreshToken: newRefreshToken };
}

export async function logout(refreshToken: string) {
  try {
    const payload = verifyRefreshToken(refreshToken);
    await revokeSession(payload.sid);
  } catch {
    // Already invalid/expired - logging out is idempotent either way.
  }
}

export async function logoutAll(userId: string) {
  await revokeAllSessions(userId);
}

export async function getMe(userId: string) {
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) throw ApiError.notFound("User not found");
  return publicUser(user);
}
