# Flipt Stale Flag Snapshot Reproduction

Reproduction of a bug in Flipt's file storage backend where the client SDK receives stale feature flag data due to incorrect ETag generation.

## The Bug

When Flipt uses file-based storage (local, git, S3, OCI) with **multiple files contributing to the same namespace**, the server computes the namespace ETag incorrectly. In `internal/storage/fs/snapshot.go`, `addDoc()` overwrites `ns.etag` with each file's ETag as files are walked alphabetically. Only the **last file's ETag** survives.

If you modify a file that comes before the last one alphabetically, the namespace ETag doesn't change. The client SDK sends the cached ETag, gets `304 Not Modified`, and returns **stale flag data** indefinitely.

**Affected versions:** Flipt v1.48.0 through v1.59.1 (fixed in v1.59.2 via [PR #4500](https://github.com/flipt-io/flipt/pull/4500)). Also all v2.x through v2.7.0 (fix never ported). This repo uses **v1.55.1**.

## Quick Start

```bash
# One command — builds, starts, toggles, and verifies the bug
./scripts/reproduce-bug.sh
```

**Prerequisites:** Docker and Docker Compose.

The script takes ~2-3 minutes (mostly Docker build time on first run) and prints a clear PASS/FAIL verdict.

## Manual Reproduction

```bash
# 1. Start the stack
docker compose up --build -d

# 2. Watch app logs — should see test-flag=false every 3s
docker compose logs -f app

# 3. In another terminal, toggle the flag
./scripts/toggle-flag.sh

# 4. Back in the app logs — test-flag stays false (stale!)

# 5. Confirm: Flipt returned 304 after the toggle
docker compose logs lb | grep snapshot

# 6. Tear down
docker compose down -v --remove-orphans
```

## How It Works

### Setup

Two feature flag files in the same namespace, stored in MinIO (S3-compatible):

| File | Flag | Alphabetical Order |
|------|------|--------------------|
| `flags.features.yml` | `test-flag` (the one we toggle) | First |
| `other.features.yml` | `disabled-flag` (never changes) | Last |

Flipt walks files alphabetically: `flags.features.yml` then `other.features.yml`. After processing both, the namespace ETag equals `other.features.yml`'s ETag only.

### Reproduction Flow

```
                    flags.features.yml    other.features.yml    Namespace ETag
                    ──────────────────    ──────────────────    ──────────────
Before toggle:      etag-A                etag-B                etag-B (bug: only last file)
After toggle:       etag-C (changed!)     etag-B (unchanged)    etag-B (unchanged!)
                                                                  ↑ SDK sends etag-B
                                                                  ↑ Server returns 304
                                                                  ↑ SDK keeps stale data
```

1. `docker compose up` starts MinIO, 3 Flipt instances, nginx load balancer, and the app
2. App evaluates `test-flag` every 3s via `flipt-client-java` SDK → `false`
3. `toggle-flag.sh` uploads modified `flags.features.yml` to MinIO with `enabled: true`
4. Flipt polls MinIO every 5s, detects the file change, rebuilds its snapshot
5. SDK polls every 30s, sends cached ETag → gets `304 Not Modified` → **stale `false`**
6. Flag change is never picked up until the client is restarted or `other.features.yml` also changes

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  MinIO (S3)                                                 │
│  ┌─────────────────────┐  ┌──────────────────────┐         │
│  │ flags.features.yml  │  │ other.features.yml   │         │
│  │ test-flag: false     │  │ disabled-flag: false │         │
│  └─────────────────────┘  └──────────────────────┘         │
└────────────────────────────┬────────────────────────────────┘
                             │ S3 polling (5s)
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
         ┌─────────┐   ┌─────────┐   ┌─────────┐
         │ flipt-1 │   │ flipt-2 │   │ flipt-3 │
         └────┬────┘   └────┬────┘   └────┬────┘
              └──────────────┼──────────────┘
                             │
                        ┌────┴────┐
                        │  nginx  │ (LB, HTTPS)
                        └────┬────┘
                             │
                        ┌────┴────┐
                        │   app   │ (Spring Boot)
                        │ SDK 30s │ (flipt-client-java)
                        └─────────┘
```

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/reproduce-bug.sh` | Automated end-to-end reproduction with verdict |
| `scripts/toggle-flag.sh` | Toggle `test-flag` in MinIO via `mc` (MinIO client) |
| `scripts/generate-keys.sh` | Generate RSA keys for identity server |
| `scripts/generate-tls-certs.sh` | Generate TLS certs (runs automatically in Docker) |

## Tech Stack

- **App:** Kotlin, Java 25, Spring Boot 4.0.1, flipt-client-java 1.2.1 (local JAR)
- **Infrastructure:** Docker Compose, MinIO (S3), Flipt v1.55.1, nginx
- **Build:** Gradle with Kotlin DSL
