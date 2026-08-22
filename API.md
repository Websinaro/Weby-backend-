# Weby API Reference

Base URL: `{HOST}/api/v1`
Unversioned: `GET {HOST}/health`, `GET {HOST}/health/ready`

All responses use a consistent envelope:

```json
// success
{ "success": true, "data": { } }

// error
{ "success": false, "error": { "code": "SOME_CODE", "message": "Human readable message" } }
```

Authenticated routes require `Authorization: Bearer <accessToken>`.

---

## Auth — `/auth`

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/auth/register` | – | `{ name, email, password }` → creates user, returns tokens |
| POST | `/auth/login` | – | `{ email, password }` → returns tokens |
| POST | `/auth/google` | – | `{ idToken }` (verified server-side against Google) → returns tokens |
| POST | `/auth/refresh` | – | `{ refreshToken }` → rotates and returns new tokens |
| POST | `/auth/logout` | – | `{ refreshToken }` → revokes that session |
| POST | `/auth/logout-all` | ✅ | Revokes every session for the current user |
| GET | `/auth/me` | ✅ | Returns the current user's safe profile |

Register/login response shape:
```json
{
  "success": true,
  "data": {
    "user": { "id": "...", "email": "...", "name": "...", "avatarUrl": null, "authProvider": "EMAIL", "emailVerified": false },
    "accessToken": "eyJ...",
    "refreshToken": "eyJ..."
  }
}
```

## Users — `/users`

| Method | Path | Auth | Description |
|---|---|---|---|
| PATCH | `/users/me` | ✅ | `{ name?, avatarUrl? }` → update profile |

## Conversations — `/conversations`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/conversations?page=1&limit=20` | ✅ | Paginated list, newest-updated first |
| POST | `/conversations` | ✅ | `{ title? }` → create |
| GET | `/conversations/:id` | ✅ | Get one (owner only, else 404) |
| DELETE | `/conversations/:id` | ✅ | Delete (owner only) |
| GET | `/conversations/:id/messages?page=1&limit=50` | ✅ | Paginated messages, oldest first |
| POST | `/conversations/:id/messages` | ✅ | `{ role: user\|assistant\|system, content, provider? }` |

## Messages — `/messages`

| Method | Path | Auth | Description |
|---|---|---|---|
| DELETE | `/messages/:id` | ✅ | Delete a single message (owner only) |

## Preferences — `/preferences`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/preferences` | ✅ | Get cloud-synced preferences (created with defaults on first access) |
| PATCH | `/preferences` | ✅ | Partial update: `assistantName, wakeWord, language, voice, voiceVerificationEnabled, theme, aiProvider, aiModel` |

Device-only settings (installed apps, contacts, relationship mappings like "bro" → contact) are **not** part of this API by design — they never leave the device.

## AI — `/ai`

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/ai/chat` | ✅ | `{ prompt, conversationId?, provider? }` → routed AI response |

If `conversationId` is supplied, the user prompt and assistant reply are both persisted and recent history (last 20 messages) is sent to the provider for context. `provider` overrides the user's default for this one call (`gemini` or `huggingface`); omit it to use the user's saved preference, falling back to the server's `DEFAULT_AI_PROVIDER`, falling back automatically to any other configured provider if the preferred one errors out.

Response:
```json
{ "success": true, "data": { "text": "...", "provider": "gemini", "model": "gemini-1.5-flash" } }
```

## Health

| Method | Path | Description |
|---|---|---|
| GET | `/health` | Liveness — `{ "status": "ok" }` |
| GET | `/health/ready` | Readiness — also checks DB connectivity |

## Error codes

| Code | HTTP | Meaning |
|---|---|---|
| VALIDATION_ERROR | 400 | Request body/query/params failed schema validation |
| INVALID_CREDENTIALS | 401 | Wrong email/password (generic, avoids enumeration) |
| TOKEN_INVALID / SESSION_INVALID / REFRESH_TOKEN_INVALID | 401 | Bad or expired token/session |
| UNAUTHORIZED | 401 | Missing/invalid Authorization header |
| EMAIL_IN_USE | 409 | Registration or Google-link email collision |
| CONVERSATION_NOT_FOUND / MESSAGE_NOT_FOUND | 404 | Not found, or not owned by the caller |
| AI_PROVIDER_UNAVAILABLE | 400 | All configured AI providers failed |
| RATE_LIMITED | 429 | Too many requests |
| INTERNAL_ERROR | 500 | Unexpected server error (details hidden in production) |
