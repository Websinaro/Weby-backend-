// Provides a minimal, valid environment for tests so importing config/env.ts
// doesn't throw. Tests that need a real database set DATABASE_URL themselves
// (e.g. via CI secrets or a local docker-compose Postgres instance).
process.env.NODE_ENV = "test";
process.env.DATABASE_URL =
  process.env.DATABASE_URL ?? "postgresql://weby:weby@localhost:5432/weby_test?schema=public";
process.env.JWT_ACCESS_SECRET = process.env.JWT_ACCESS_SECRET ?? "test-access-secret-please-ignore";
process.env.JWT_REFRESH_SECRET = process.env.JWT_REFRESH_SECRET ?? "test-refresh-secret-please-ignore";
process.env.CORS_ORIGIN = "http://localhost:3000";
