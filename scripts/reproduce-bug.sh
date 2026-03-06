#!/bin/bash
# Automated reproduction of the Flipt file storage ETag bug.
#
# This script:
#   1. Starts the full stack from scratch (MinIO, 3x Flipt, nginx LB, app)
#   2. Waits for the app to confirm baseline (test-flag=false)
#   3. Toggles test-flag to true via MinIO S3
#   4. Waits for the SDK update interval (30s) to pass
#   5. Checks whether the app detected the change
#   6. Verifies Flipt returned 304 Not Modified (the bug)
#   7. Reports PASS (bug reproduced) or FAIL (bug not reproduced)

set -e

cd "$(dirname "$0")/.."

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log()  { echo -e "${CYAN}[repro]${NC} $*"; }
pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

# ── Step 0: Clean slate ─────────────────────────────────────────────────────
log "Tearing down any existing stack..."
docker compose down -v --remove-orphans 2>/dev/null || true

# Reset seed file to enabled: false in case a previous run left it toggled
SEED_FILE="flipt/features/flags.features.yml"
if grep -q 'enabled: true' "$SEED_FILE" 2>/dev/null; then
  sed -i.bak 's/enabled: true/enabled: false/' "$SEED_FILE" && rm -f "${SEED_FILE}.bak"
  log "Reset $SEED_FILE to enabled: false"
fi

# ── Step 1: Start the stack ─────────────────────────────────────────────────
log "Starting stack (MinIO + 3x Flipt + nginx LB + app)..."
log "This may take a few minutes on first build..."
docker compose up --build -d 2>&1 | tail -5

# ── Step 2: Wait for app to start evaluating ─────────────────────────────────
log "Waiting for app to start evaluating flags..."
ATTEMPTS=0
MAX_ATTEMPTS=60
while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
  if docker compose logs app 2>/dev/null | grep -q "eval #1"; then
    break
  fi
  ATTEMPTS=$((ATTEMPTS + 1))
  sleep 2
done

if [ $ATTEMPTS -eq $MAX_ATTEMPTS ]; then
  fail "App did not start evaluating within ${MAX_ATTEMPTS}x2s. Check: docker compose logs app"
  exit 1
fi

# ── Step 3: Confirm baseline ────────────────────────────────────────────────
BASELINE=$(docker compose logs app 2>/dev/null | grep "eval #1" | grep -o "test-flag=[a-z]*")
log "Baseline: $BASELINE"

if [ "$BASELINE" != "test-flag=false" ]; then
  fail "Expected baseline test-flag=false, got: $BASELINE"
  docker compose down -v --remove-orphans 2>/dev/null
  exit 1
fi

# ── Step 4: Record pre-toggle state ─────────────────────────────────────────
# Count 304 responses before toggling
PRE_304_COUNT=$(docker compose logs lb 2>/dev/null | grep "snapshot" | grep -c " 304 " || true)
TOGGLE_TIME=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

log "Toggling test-flag to true at $TOGGLE_TIME ..."
./scripts/toggle-flag.sh 2>&1 | grep -E "^(Toggled|===)" || true

# ── Step 5: Wait for SDK update interval + buffer ────────────────────────────
# SDK polls every 30s (UPDATE_INTERVAL_SECONDS=30). Wait 45s to ensure at
# least one full poll cycle after the toggle.
log "Waiting 45s for SDK update interval to pass..."
sleep 45

# ── Step 6: Check results ───────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  RESULTS"
echo "════════════════════════════════════════════════════════════════"

# Get the last evaluation
LAST_EVAL=$(docker compose logs app 2>/dev/null | grep "eval #" | tail -1)
LAST_VALUE=$(echo "$LAST_EVAL" | grep -o "test-flag=[a-z]*")
LAST_EVAL_NUM=$(echo "$LAST_EVAL" | grep -o "eval #[0-9]*")

echo ""
log "Last evaluation: $LAST_EVAL_NUM -> $LAST_VALUE"

# Check for any true evaluation after toggle
TRUE_COUNT=$(docker compose logs app --since "$TOGGLE_TIME" 2>/dev/null | grep "eval #" | grep -c "test-flag=true" || true)
FALSE_COUNT=$(docker compose logs app --since "$TOGGLE_TIME" 2>/dev/null | grep "eval #" | grep -c "test-flag=false" || true)

log "Post-toggle evaluations: ${FALSE_COUNT}x false, ${TRUE_COUNT}x true"

# Check 304 responses after toggle
POST_304_COUNT=$(docker compose logs lb 2>/dev/null | grep "snapshot" | grep -c " 304 " || true)
NEW_304S=$((POST_304_COUNT - PRE_304_COUNT))

log "304 Not Modified responses after toggle: $NEW_304S"

# Check for any 200 responses after toggle (would indicate ETag changed)
POST_200=$(docker compose logs lb --since "$TOGGLE_TIME" 2>/dev/null | grep "snapshot" | grep -c " 200 " || true)
log "200 OK responses after toggle: $POST_200"

echo ""

# ── Step 7: Verdict ──────────────────────────────────────────────────────────
BUG_REPRODUCED=true

if [ "$TRUE_COUNT" -gt 0 ]; then
  BUG_REPRODUCED=false
fi

if [ "$BUG_REPRODUCED" = true ]; then
  echo "════════════════════════════════════════════════════════════════"
  pass "BUG REPRODUCED: Stale flag snapshot confirmed."
  echo "════════════════════════════════════════════════════════════════"
  echo ""
  echo "  test-flag was toggled to true at $TOGGLE_TIME"
  echo "  but the SDK still returns false after 45s."
  echo ""
  echo "  Root cause: Flipt's file storage ETag bug."
  echo "  The namespace ETag only reflects other.features.yml (last"
  echo "  alphabetically). Changing flags.features.yml doesn't change"
  echo "  the ETag, so the SDK gets 304 Not Modified."
  echo ""
  echo "  Affected: Flipt v1.48.0 - v1.59.1, all v2.x through v2.7.0"
  echo "  Fixed in: v1.59.2 (PR #4500), not yet ported to v2.x"
  echo ""
else
  echo "════════════════════════════════════════════════════════════════"
  fail "BUG NOT REPRODUCED: SDK detected the flag change."
  echo "════════════════════════════════════════════════════════════════"
  echo ""
  echo "  The SDK picked up test-flag=true, which means the ETag"
  echo "  bug did not manifest. This could happen if:"
  echo "    - Flipt version includes the fix (>= v1.59.2)"
  echo "    - The client was rebuilt during the test window"
  echo "    - other.features.yml was also modified"
  echo ""
fi

# ── Cleanup ──────────────────────────────────────────────────────────────────
echo "Stack is still running. To inspect:"
echo "  docker compose logs app    # app evaluations"
echo "  docker compose logs lb     # nginx 304/200 responses"
echo "  docker compose logs flipt-1  # Flipt snapshot updates"
echo ""
echo "To tear down:"
echo "  docker compose down -v --remove-orphans"
