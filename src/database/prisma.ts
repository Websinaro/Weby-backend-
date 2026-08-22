import { PrismaClient } from "@prisma/client";
import { isProduction } from "../config/env";

// A single shared Prisma client instance, reused across the app.
// In development we attach it to globalThis to survive hot-reloads
// without exhausting database connections.
declare global {
  // eslint-disable-next-line no-var
  var __prisma__: PrismaClient | undefined;
}

export const prisma =
  global.__prisma__ ??
  new PrismaClient({
    log: isProduction ? ["error", "warn"] : ["warn", "error"],
  });

if (!isProduction) {
  global.__prisma__ = prisma;
}
