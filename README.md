# Weby Backend

Node.js / TypeScript / Express / Prisma / PostgreSQL API powering the Weby voice assistant.

## Stack

- **Runtime:** Node.js 20+, TypeScript (strict mode)
- **Framework:** Express 4
- **ORM:** Prisma + PostgreSQL
- **Auth:** Argon2id password hashing, JWT access + refresh tokens (rotated), Google Sign-In (server-verified)
- **Validation:** Zod on every external input
- **Security:** Helmet, CORS allowlist, rate limiting, structured logging with secret redaction
- **AI:** Provider abstraction (Gemini, Hugging Face) behind a fallback-aware router

## Getting started (local development)

```bash
cp .env.example .env        # fill in DATABASE_URL, JWT secrets, etc.
npm install
docker compose up -d postgres   # or point DATABASE_URL at your own Postgres
npx prisma migrate dev --name init
npm run dev                 # http://localhost:3000
```

Generate strong JWT secrets:

```bash
openssl rand -hex 64
```

## Getting started (Docker, full stack)

```bash
cp .env.example .env
docker compose up --build
```

This builds the backend image and starts Postgres + the API together. On container start, `prisma migrate deploy` runs automatically before the server boots.

## Scripts

| Command | Description |
|---|---|
| `npm run dev` | Start with hot reload (tsx) |
| `npm run build` | Compile TypeScript to `dist/` |
| `npm start` | Run the compiled build |
| `npm test` | Run Jest test suite |
| `npm run prisma:migrate` | Create/apply a dev migration |
| `npm run prisma:deploy` | Apply migrations in production |
| `npm run prisma:studio` | Open Prisma Studio DB browser |

## Testing

`tests/health.test.ts` runs with no external dependencies.

`tests/auth.test.ts` and `tests/conversations.test.ts` need a real Postgres database (they exercise real registration, login, token rotation, and cross-user access-control behavior — not mocks). Point `DATABASE_URL` at a disposable test database before running:

```bash
DATABASE_URL="postgresql://weby:weby@localhost:5432/weby_test?schema=public" npx prisma migrate deploy
npm test
```

## Deployment

The backend is a standard containerized Node service — deployable to **Railway, Fly.io, a VPS, or any Docker-friendly host**.

**Why not Vercel:** Vercel's serverless functions are stateless and short-lived, which fits poorly with this API's persistent Postgres connections, session/refresh-token model, and (future) WebSocket usage. It *can* be adapted to Vercel's serverless runtime, but that requires connection pooling (e.g. Prisma Accelerate/PgBouncer) and reworking a few things. Railway or Fly.io run the Dockerfile as-is with a normal long-lived process, are the simplest path to "just works," and (per your note about inactivity) don't spin down on idle the way some free tiers do.

Steps for Railway/Fly.io:
1. Provision a PostgreSQL instance (both platforms offer one).
2. Set all variables from `.env.example` in the platform's environment settings.
3. Deploy the `backend/` directory — the included `Dockerfile` handles build, migration, and startup.
4. Point your Flutter app's API base URL at the deployed service.

## API Documentation

See [`API.md`](./API.md) for the full endpoint reference.

## Security notes

- Passwords: Argon2id, never logged, never returned.
- Refresh tokens: only a SHA-256 hash is stored; tokens rotate on every refresh.
- AI provider API keys live only in this backend's environment — they are never sent to or accepted from the Flutter client.
- Every conversation/message/preference query is scoped to `req.userId`, sourced only from a verified access token, never from client-supplied IDs.
