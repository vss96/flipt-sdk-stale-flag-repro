#!/bin/bash
# Toggle the test-flag in MinIO S3 storage.
# Downloads flags.yml from MinIO, toggles the value, and uploads it back.
# Flipt polls S3 every 5s and picks up the change.

set -e

cd "$(dirname "$0")/.."

MC_RUN="docker compose run --rm -T --entrypoint sh mc -c"
MC_ALIAS="mc alias set m http://minio:9000 minioadmin minioadmin >/dev/null 2>&1"

# Download current flags.yml from MinIO
CONTENT=$($MC_RUN "$MC_ALIAS && mc cat m/flipt/flags.features.yml")

# Read current state
CURRENT=$(echo "$CONTENT" | grep -A3 'key: test-flag' | grep 'enabled:' | awk '{print $2}')

echo "=== Flag Toggle ==="
echo "Current test-flag enabled: $CURRENT"
echo "Toggling at: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"

if [ "$CURRENT" = "true" ]; then
  NEW_CONTENT=$(echo "$CONTENT" | awk '/key: test-flag/{found=1} found && /enabled:/{sub(/enabled: true/, "enabled: false"); found=0} 1')
  echo "Toggled test-flag: true → false"
else
  NEW_CONTENT=$(echo "$CONTENT" | awk '/key: test-flag/{found=1} found && /enabled:/{sub(/enabled: false/, "enabled: true"); found=0} 1')
  echo "Toggled test-flag: false → true"
fi

# Upload modified file back to MinIO
echo "$NEW_CONTENT" | $MC_RUN "$MC_ALIAS && mc pipe m/flipt/flags.features.yml"

echo ""
echo "Updated flags.yml uploaded to MinIO."
echo "Flipt will poll and pick up the change within poll_interval (5s)."
echo "If the ETag bug reproduces, the SDK will NOT detect the change."
