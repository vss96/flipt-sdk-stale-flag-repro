# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

Test project for verifying `flipt-client-java` 1.3.1's `AuthenticationProvider`/`AuthenticationLease` API — specifically whether the SDK correctly refreshes JWT tokens before expiry without rebuilding the client.

## Build & Run

**Prerequisites:** Java 25 (via SDKMAN: `sdk env install`), Docker/Docker Compose.

```bash
./gradlew build                    # Build everything
docker compose up --build -d       # Start stack (Flipt + identity-server + app)
docker compose logs -f app         # Watch flag evaluations + auth lease refresh
./scripts/toggle-flag.sh           # Toggle test-flag via Flipt API
docker compose down -v --remove-orphans  # Tear down

# Build individual modules
./gradlew :app:bootJar
./gradlew :identity-server:bootJar

# Generate RSA keys (run once, keys persist in keys/)
./scripts/generate-keys.sh
```

There are no tests — this is a debugging/verification project.

**What to watch for in logs:**
- `[auth-lease] Fetching JWT from identity server` — on startup and every ~90s (refresh 30s before 2-min expiry)
- `[auth-lease] Got JWT, expires at ... (in 120s)` — confirms token was obtained
- `[eval #N] test-flag=false` — flag evaluation every 3s
- `FLAG VALUE CHANGED` — after running `toggle-flag.sh`

## Architecture

**Two Gradle subprojects:**

- **`app`** — Spring Boot app that uses `flipt-client-java` SDK to evaluate feature flags on a 3-second schedule. Key classes:
  - `FliptClientProvider` — creates FliptClient with `authenticationProvider` lambda that fetches JWTs from the identity server; the SDK handles refresh internally 30s before token expiry
  - `FeatureFlagService` — scheduled consumer that evaluates `test-flag` every 3s and logs value changes
  - `AppProperties` — config properties under `flipt.*` prefix (url, identity-server-url, update-interval-seconds)

- **`identity-server`** — Spring Boot app (port 9090) that issues RS256 JWTs via `GET /token` with configurable expiry (default 2 minutes). Returns `{"token": "...", "expires_at": "..."}`.

**Infrastructure (docker-compose.yml):**

- Single Flipt instance (v1.55.1) with default SQLite storage and both token + JWT auth enabled
- `generate-keys` init container creates RSA key pair if not present
- `seed-flags` init container creates `test-flag` via Flipt HTTP API
- Identity server issues 2-min JWTs signed with the RSA private key; Flipt validates with the public key
- Flipt config in `flipt/config.yml` — JWT auth with `public_key_file`, token auth with bootstrap token `test-token-123`
- `toggle-flag.sh` uses Flipt's HTTP API with the bootstrap token

## Tech Stack

- Kotlin 2.2.21, Java 25, Spring Boot 4.0.1
- Gradle with Kotlin DSL
- flipt-client-java 1.3.1 (Maven Central) with AuthenticationLease API
- Docker Compose for infrastructure
- Flipt v1.55.1 with SQLite storage
