import { getFirebaseApp } from "../../config/firebase";
import { ApiError } from "../../utils/ApiError";

export interface VerifiedGoogleIdentity {
  googleId: string;
  email: string;
  emailVerified: boolean;
  name: string;
  avatarUrl?: string;
}

// Verifies a Firebase ID token SERVER-SIDE using Firebase's public keys.
// The client obtains this token by signing in with Google through
// firebase_auth on-device, then calling user.getIdToken(). This is the
// only source of truth for "who is this Google user" - we deliberately
// ignore any email/name the client might also send alongside the token
// (spec: never trust a frontend-supplied identity).
export async function verifyGoogleIdToken(idToken: string): Promise<VerifiedGoogleIdentity> {
  const app = getFirebaseApp();
  if (!app) {
    throw ApiError.internal(
      "Google sign-in is not configured on this server",
      "GOOGLE_NOT_CONFIGURED"
    );
  }

  let decoded;
  try {
    decoded = await app.auth().verifyIdToken(idToken);
  } catch {
    throw ApiError.unauthorized("Invalid Google credential", "INVALID_GOOGLE_TOKEN");
  }

  // Confirm the token was actually minted via the Google sign-in provider,
  // not some other Firebase-supported provider (email link, phone, etc.) -
  // this endpoint is Google-sign-in-only.
  const signInProvider = decoded.firebase?.sign_in_provider;
  if (signInProvider !== "google.com") {
    throw ApiError.unauthorized("Invalid Google credential", "INVALID_GOOGLE_TOKEN");
  }

  if (!decoded.sub || !decoded.email) {
    throw ApiError.unauthorized("Invalid Google credential", "INVALID_GOOGLE_TOKEN");
  }

  return {
    googleId: decoded.sub,
    email: decoded.email.toLowerCase(),
    emailVerified: Boolean(decoded.email_verified),
    name: (decoded.name as string | undefined) ?? decoded.email.split("@")[0],
    avatarUrl: decoded.picture as string | undefined,
  };
}
