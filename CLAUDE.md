# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

Reproduction project (`flipt-sdk-stale-flag-repro`) for investigating stale feature flag snapshots in `flipt-client-java`. It simulates a production-like setup with multiple Flipt instances behind an nginx load balancer (with TLS), a Spring Boot app that periodically evaluates flags, and an identity server for JWT-based authentication.

## Build & Run

**Prerequisites:** Java 25 (via SDKMAN: `sdk env install`), Docker/Docker Compose.

```bash
# Build everything
./gradlew build

# Build individual modules
./gradlew :app:bootJar
./gradlew :identity-server:bootJar

# Run the full stack (Postgres, 3x Flipt, nginx LB, app)
docker compose up --build

# Toggle the test-flag to test change detection
./scripts/toggle-flag.sh

# Generate RSA keys for identity server (run once, keys persist in keys/)
./scripts/generate-keys.sh
```

There are no tests — this is a reproduction/debugging project.

## Architecture

**Two Gradle subprojects:**

- **`app`** — Spring Boot app (port 8081) that uses `flipt-client-java` SDK to evaluate feature flags on a 3-second schedule. Key classes:
  - `FliptClientProvider` — manages FliptClient lifecycle with token expiry tracking, double-checked locking for client rebuild
  - `FeatureFlagService` — scheduled consumer that evaluates `test-flag` every 3s and logs value changes
  - `AppProperties` — config properties under `flipt.*` prefix (url, identity-server-url, update-interval-seconds)
  - Uses a **local JAR** at `app/libs/flipt-client-java-1.2.1.jar` (not from Maven Central)

- **`identity-server`** — Spring Boot app (port 9090) that issues RS256 JWTs via `GET /token`. Uses nimbus-jose-jwt library.

**Infrastructure (docker-compose.yml):**

- 3 Flipt instances (`flipt-1`, `flipt-2`, `flipt-3`) sharing a Postgres database, with token auth enabled (bootstrap token: `test-token-123`)
- nginx load balancer (`lb`) fronting the Flipt instances — HTTPS on port 8443, HTTP on port 8080
- TLS certs auto-generated at startup via `generate-tls-certs` init container
- Feature flags seeded from `flipt/features.yml` on first Flipt startup (`flipt-1` runs import)
- Flipt config in `flipt/config.yml`

**Key detail:** The `toggle-flag.sh` script modifies `flipt/features.yml` locally but Flipt uses **database storage** (not filesystem), so toggling requires the Flipt API. The script uses `sed`/`awk` on the local file. To toggle via API, use the Flipt HTTP API through the load balancer at `localhost:8080`.

## Tech Stack

- Kotlin 2.2.21, Java 25, Spring Boot 4.0.1
- Gradle with Kotlin DSL
- flipt-client-java 1.2.1 (local JAR with JNA native bindings)
- Docker Compose for infrastructure
