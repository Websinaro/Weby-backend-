import { OAuth2Client } from "google-auth-library";
import { env } from "../../config/env";
import { ApiError } from "../../utils/ApiError";

const client = env.GOOGLE_CLIENT_ID ? new OAuth2Client(env.GOOGLE_CLIENT_ID) : null;

export interface VerifiedGoogleIdentity {
  googleId: string;
  email: string;
  emailVerified: boolean;
  name: string;
  avatarUrl?: string;
}

// Verifies a Google ID token SERVER-SIDE using Google's public keys.
// This is the only source of truth for "who is this Google user" -
// we deliberately ignore any email/name the client might also send
// alongside the token (spec: never trust a frontend-supplied email).
export async function verifyGoogleIdToken(idToken: string): Promise<VerifiedGoogleIdentity> {
  if (!client) {
    throw ApiError.internal(
      "Google sign-in is not configured on this server",
      "GOOGLE_NOT_CONFIGURED"
    );
  }

  let ticket;
  try {
    ticket = await client.verifyIdToken({
      idToken,
      audience: env.GOOGLE_CLIENT_ID,
    });
  } catch {
    throw ApiError.unauthorized("Invalid Google credential", "INVALID_GOOGLE_TOKEN");
  }

  const payload = ticket.getPayload();
  if (!payload || !payload.sub || !payload.email) {
    throw ApiError.unauthorized("Invalid Google credential", "INVALID_GOOGLE_TOKEN");
  }

  return {
    googleId: payload.sub,
    email: payload.email.toLowerCase(),
    emailVerified: Boolean(payload.email_verified),
    name: payload.name ?? payload.email.split("@")[0],
    avatarUrl: payload.picture,
  };
}
