# RunFuel Android architecture and delivery plan

The canonical source for new self-hosted installations is **https://github.com/minitombo/runfuel-mcp-public**.

## Product decisions

- Flutter Android app; Android first.
- OpenAI is the AI provider, called only through a secure backend proxy.
- Offline-first local cache; manual synchronisation only in v1.
- Existing RunFuel MCP remains available to MCP clients.
- New installations/deployments originate from this public repository.
- No maintainer Vercel project, Redis database, credentials, API keys or cookies are reused by forks.
- GPS geometry is excluded from routine responses and fetched only after explicit route-analysis intent.
- Health documents are sensitive: upload only after explicit user action and consent.

## Architecture

1. Flutter client: screens, local cache, user-initiated sync, file selection, coaching UI.
2. Mobile API: authenticated endpoints added to the RunFuel backend; do not expose raw MCP credentials to the client.
3. Integration layer: reuse existing Garmin and MyFitnessPal adapters server-side.
4. AI gateway: server-side OpenAI Responses API calls with narrow function allow-list, usage limits and redaction.
5. Local store: structured training/nutrition summaries and saved reviews; health files require encrypted storage.
6. Setup manager: GitHub/Vercel OAuth or delegated authorization, project selection, environment checks and deployment verification. No personal access tokens embedded in the APK.

## Mobile API contract to implement

All endpoints require a per-installation app session and use compact responses. Do not return upstream cookies or long-lived provider tokens.

- `GET /api/mobile/v1/status` — backend health and integration status (never disclose secrets).
- `POST /api/mobile/v1/sync/garmin` — explicit user-initiated Garmin sync.
- `POST /api/mobile/v1/sync/myfitnesspal` — explicit user-initiated MFP sync.
- `GET /api/mobile/v1/summary?date=YYYY-MM-DD` — compact dashboard summary from cached/retrieved data.
- `GET /api/mobile/v1/training?from=...&to=...` — scheduled and completed sessions.
- `GET /api/mobile/v1/nutrition?date=...` — selected diary summary.
- `POST /api/mobile/v1/coach` — OpenAI Responses API proxy; only requested data scopes are provided.
- `POST /api/mobile/v1/health/documents` — explicit, consented upload; strict type/size limits and private storage.
- `GET /api/mobile/v1/health/documents` and `DELETE /api/mobile/v1/health/documents/{id}` — user-managed records.
- `GET /api/mobile/v1/connections` — status and last validation timestamps.
- `POST /api/mobile/v1/connections/{provider}/check` — verify credentials without returning them.
- `POST /api/mobile/v1/connections/{provider}/refresh` — only where provider supports a refresh flow.

The existing MCP `/mcp` endpoint is not itself a mobile REST API. Do not have the APK call MCP with copied personal tokens as a shortcut.

## Authentication and security

- Keep OpenAI, Vercel, Garmin and MyFitnessPal secrets server-side.
- App pairing should use a short-lived, one-time code or OAuth authorization flow.
- Store only a revocable app session token in Android Keystore-backed secure storage.
- Never store medical files unencrypted. Encrypt at rest; use private object storage or a bounded secure upload flow, with explicit user consent and deletion.
- Never automatically upload selected screenshots/documents.
- For AI document analysis, show exactly which selected file and extracted information will be sent.
- Return source/date/unit/reference-range provenance for lab results; distinguish transcription from interpretation.
- Token expiry is not always knowable for cookies. Detect rejected authentication on a controlled connection check and prompt for renewal.
- Rate-limit endpoints and apply per-user AI budget limits server-side.

## Build sequence

1. Flutter shell and APK CI (current foundation).
2. Mobile API and secure app pairing.
3. Manual Garmin and MyFitnessPal sync plus local cache.
4. OpenAI coach, tool calling, usage limits and saved reviews.
5. Encrypted health vault, file uploads and image/PDF analysis.
6. GitHub/Vercel setup wizard, token manager links, deployment checks and token renewal prompts.
7. Device testing, security review and release APK.

## Current app status

The initial Flutter UI foundation is under `app/`. It intentionally does not claim that sync, AI, uploads, or deployment setup are live until their backend contracts are implemented and tested.
