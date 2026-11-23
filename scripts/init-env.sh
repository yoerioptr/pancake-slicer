#!/usr/bin/env bash
set -euo pipefail

# .env contains the bearer token. Keep all created files private.
umask 077

# Ensure we are in the project root.
cd "$(dirname "$0")/.."

ENV_FILE=".env"
EXAMPLE_FILE=".env.example"

if [ -f "$ENV_FILE" ]; then
    echo "Error: $ENV_FILE already exists; refusing to overwrite it."
    exit 1
fi

cp "$EXAMPLE_FILE" "$ENV_FILE"

if command -v openssl &> /dev/null; then
    TOKEN=$(openssl rand -hex 32)
else
    TOKEN=$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')
fi

TMP_FILE=".env.tmp.$$"
trap 'rm -f "$TMP_FILE"' EXIT

awk -v token="$TOKEN" '
    BEGIN { replaced = 0 }
    index($0, "PANCAKE_BEARER_TOKEN" "=") == 1 {
        print "PANCAKE_BEARER_TOKEN" "=" token
        replaced = 1
        next
    }
    { print }
    END {
        if (!replaced) {
            print "PANCAKE_BEARER_TOKEN" "=" token
        }
    }
' "$ENV_FILE" > "$TMP_FILE"

mv "$TMP_FILE" "$ENV_FILE"
chmod 600 "$ENV_FILE"

echo "Created $ENV_FILE from $EXAMPLE_FILE with a generated PANCAKE_BEARER_TOKEN."
echo "The token protects mutation requests. If you use a reverse proxy that"
echo "injects its own Authorization header, clear PANCAKE_BEARER_TOKEN instead."
echo "Review PANCAKE_DATA_PATH, PANCAKE_CACHE_PATH, PANCAKE_PORT, TZ, and then run:"
echo "  ./scripts/render-compose.sh"
