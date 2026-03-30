#!/bin/sh
# Seed initial feature flags via Flipt HTTP API.
# Called by docker-compose as an init container after Flipt is healthy.

set -e

FLIPT_URL="${FLIPT_URL:-http://flipt:8080}"
AUTH_TOKEN="${FLIPT_AUTH_TOKEN:-test-token-123}"

echo "Seeding flags via Flipt API at $FLIPT_URL..."

# Create test-flag (boolean, initially disabled)
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST "$FLIPT_URL/api/v1/namespaces/default/flags" \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"key":"test-flag","name":"Test Flag","type":"BOOLEAN_FLAG_TYPE","enabled":false}')

if [ "$HTTP_CODE" = "200" ]; then
  echo "Created test-flag (enabled=false)"
elif [ "$HTTP_CODE" = "409" ]; then
  echo "test-flag already exists, skipping"
else
  echo "Failed to create test-flag: HTTP $HTTP_CODE"
  exit 1
fi

echo "Flag seeding complete."
