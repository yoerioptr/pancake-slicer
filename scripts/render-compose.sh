#!/usr/bin/env bash
set -euo pipefail

# Configuration
TEMPLATE_FILE="compose/compose.template.yaml"
ENV_FILE=".env"
OUTPUT_DIR="build"
OUTPUT_FILE="${OUTPUT_DIR}/compose.yaml"
PROJECT_NAME="pancakeslicer"

# Ensure we are in the project root
cd "$(dirname "$0")/.."

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: $ENV_FILE not found. Create it from .env.example first." >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "Rendering $TEMPLATE_FILE to $OUTPUT_FILE..."

if docker compose version >/dev/null 2>&1; then
    docker compose \
        --project-name "$PROJECT_NAME" \
        --env-file "$ENV_FILE" \
        -f "$TEMPLATE_FILE" \
        config > "$OUTPUT_FILE"
elif command -v docker-compose >/dev/null 2>&1; then
    docker-compose \
        --project-name "$PROJECT_NAME" \
        --env-file "$ENV_FILE" \
        -f "$TEMPLATE_FILE" \
        config > "$OUTPUT_FILE"
elif command -v envsubst >/dev/null 2>&1; then
    echo "Warning: docker compose not found; using the envsubst fallback." >&2
    set -a
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    set +a
    envsubst < "$TEMPLATE_FILE" > "$OUTPUT_FILE"
else
    echo "Error: docker compose or envsubst is required." >&2
    exit 1
fi

# The rendered file can contain a bearer token. Keep it private.
chmod 600 "$OUTPUT_FILE"

echo "Successfully rendered to $OUTPUT_FILE (mode 600)."
echo "Paste its contents into the TrueNAS Custom App YAML editor."
