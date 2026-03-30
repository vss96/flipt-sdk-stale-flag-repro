#!/bin/bash
# Toggle the test-flag via Flipt HTTP API.

set -e

FLIPT_URL="${FLIPT_URL:-http://localhost:8080}"
AUTH_TOKEN="${FLIPT_AUTH_TOKEN:-test-token-123}"

# Get current flag state
CURRENT=$(curl -s \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  "$FLIPT_URL/api/v1/namespaces/default/flags/test-flag" | \
  grep -o '"enabled":[a-z]*' | head -1 | cut -d: -f2)

echo "=== Flag Toggle ==="
echo "Current test-flag enabled: $CURRENT"
echo "Toggling at: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"

if [ "$CURRENT" = "true" ]; then
  NEW_VALUE="false"
else
  NEW_VALUE="true"
fi

curl -s -o /dev/null -w "HTTP %{http_code}\n" \
  -X PUT "$FLIPT_URL/api/v1/namespaces/default/flags/test-flag" \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"Test Flag\",\"enabled\":$NEW_VALUE}"

echo "Toggled test-flag: $CURRENT → $NEW_VALUE"
