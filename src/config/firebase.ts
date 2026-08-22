import admin from "firebase-admin";
import { env } from "./env";
import { logger } from "./logger";

/// Lazily-initialized Firebase Admin app, used solely to verify Firebase
/// ID tokens sent by the client after it signs the user in with Google.
/// We never use the Admin SDK to *issue* tokens - the client authenticates
/// directly against Firebase/Google, and the server's only job is to
/// verify the resulting ID token's signature server-side.
let app: admin.app.App | null = null;

export function getFirebaseApp(): admin.app.App | null {
  if (app) return app;

  const { FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, FIREBASE_PRIVATE_KEY } = env;

  if (!FIREBASE_PROJECT_ID || !FIREBASE_CLIENT_EMAIL || !FIREBASE_PRIVATE_KEY) {
    logger.warn(
      "Firebase Admin not configured (FIREBASE_PROJECT_ID / FIREBASE_CLIENT_EMAIL / " +
        "FIREBASE_PRIVATE_KEY missing) - Google sign-in will be unavailable."
    );
    return null;
  }

  app = admin.initializeApp({
    credential: admin.credential.cert({
      projectId: FIREBASE_PROJECT_ID,
      clientEmail: FIREBASE_CLIENT_EMAIL,
      // .env files can't hold real newlines, so service-account keys are
      // stored with literal "\n" and unescaped here.
      privateKey: FIREBASE_PRIVATE_KEY.replace(/\\n/g, "\n"),
    }),
  });

  return app;
}
