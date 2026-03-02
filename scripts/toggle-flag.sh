#!/bin/bash
# Toggle the test-flag in features.yml
# Flipt with local storage watches the filesystem, so changes propagate automatically.

set -e

FEATURES_FILE="$(dirname "$0")/../flipt/features.yml"

if [ ! -f "$FEATURES_FILE" ]; then
  echo "ERROR: features.yml not found at $FEATURES_FILE"
  exit 1
fi

# Read current state
CURRENT=$(grep -A3 'key: test-flag' "$FEATURES_FILE" | grep 'enabled:' | awk '{print $2}')

echo "=== Flag Toggle ==="
echo "Current test-flag enabled: $CURRENT"
echo "Toggling at: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"

if [ "$CURRENT" = "true" ]; then
  # Use a temp file for portable sed -i behavior
  sed 's/\(key: test-flag\)/\1/' "$FEATURES_FILE" > /dev/null
  # Toggle: find the enabled line after test-flag and change it
  awk '/key: test-flag/{found=1} found && /enabled:/{sub(/enabled: true/, "enabled: false"); found=0} 1' \
    "$FEATURES_FILE" > "${FEATURES_FILE}.tmp" && mv "${FEATURES_FILE}.tmp" "$FEATURES_FILE"
  echo "Toggled test-flag: true → false"
else
  awk '/key: test-flag/{found=1} found && /enabled:/{sub(/enabled: false/, "enabled: true"); found=0} 1' \
    "$FEATURES_FILE" > "${FEATURES_FILE}.tmp" && mv "${FEATURES_FILE}.tmp" "$FEATURES_FILE"
  echo "Toggled test-flag: false → true"
fi

echo ""
echo "New features.yml content:"
cat "$FEATURES_FILE"
echo ""
echo "Now watch the app logs for flag change detection."
echo "Expected detection within updateInterval (10s)."
echo "If it takes longer or requires client rebuild (50s), the issue is reproduced."
