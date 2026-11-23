#!/usr/bin/env bash
set -euo pipefail

TEMPLATE_FILE="compose/compose.template.yaml"
RENDERED_FILE="build/compose.yaml"
ENV_EXAMPLE=".env.example"

# Ensure we are in the project root
cd "$(dirname "$0")/.."

echo "--- Starting Validation ---"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

ok() {
    echo "OK: $*"
}

# 0. Shell syntax
echo "[0/10] Checking shell script syntax..."
bash -n scripts/*.sh
ok "Shell scripts parse cleanly."

# 1. Compose structural validation
echo "[1/10] Validating Compose template and variables..."
COMPOSE_CMD=""
if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
fi

if [ -n "$COMPOSE_CMD" ]; then
    # shellcheck disable=SC2086
    $COMPOSE_CMD --env-file "$ENV_EXAMPLE" -f "$TEMPLATE_FILE" config >/dev/null
    ok "YAML and variables are valid."
else
    echo "WARN: docker compose not found; skipping structural YAML validation."
fi

# 2. Required service
echo "[2/10] Checking required service..."
grep -qE '^  pancakeslicer:$' "$TEMPLATE_FILE" \
    || fail "Service 'pancakeslicer' is missing from $TEMPLATE_FILE."
ok "Service 'pancakeslicer' is present."

# 3. Pinned image
echo "[3/10] Checking image pin..."
grep -qF 'image: "${PANCAKE_IMAGE}:${PANCAKE_VERSION}"' "$TEMPLATE_FILE" \
    || fail "The image must be '\${PANCAKE_IMAGE}:\${PANCAKE_VERSION}'."
grep -qE '^PANCAKE_VERSION=[0-9]+\.[0-9]+\.[0-9]+$' "$ENV_EXAMPLE" \
    || fail "PANCAKE_VERSION in $ENV_EXAMPLE must be a semver tag."
if grep -qE '^PANCAKE_VERSION=latest$' "$ENV_EXAMPLE"; then
    fail "PANCAKE_VERSION must not be 'latest'."
fi
if [ -f "$RENDERED_FILE" ]; then
    if grep -qE '^[[:space:]]*image:.*:latest$' "$RENDERED_FILE"; then
        fail "$RENDERED_FILE uses a ':latest' image tag."
    fi
    if ! grep -qE '^[[:space:]]*image:.*:[0-9]+\.[0-9]+\.[0-9]+$' "$RENDERED_FILE"; then
        fail "$RENDERED_FILE does not contain a pinned semver image tag."
    fi
fi
ok "Image is pinned to a semver release."

# 4. LAN port mapping
echo "[4/10] Checking LAN port mapping..."
grep -qF '${PANCAKE_PORT}:6868' "$TEMPLATE_FILE" \
    || fail "The template must map \${PANCAKE_PORT} to container port 6868."
grep -qE '^PANCAKE_PORT=[0-9]+$' "$ENV_EXAMPLE" \
    || fail "PANCAKE_PORT must be numeric in $ENV_EXAMPLE."
ok "Port mapping is correct."

# 5. Persistent storage
echo "[5/10] Checking persistent storage..."
grep -qF '${PANCAKE_DATA_PATH}:/data' "$TEMPLATE_FILE" \
    || fail "Missing the \${PANCAKE_DATA_PATH}:/data volume mapping."
grep -qF '${PANCAKE_CACHE_PATH}:/data/jobs/stage-cache' "$TEMPLATE_FILE" \
    || fail "Missing the \${PANCAKE_CACHE_PATH}:/data/jobs/stage-cache volume mapping."
grep -qE '^PANCAKE_DATA_PATH=/mnt/' "$ENV_EXAMPLE" \
    || fail "PANCAKE_DATA_PATH should be under /mnt on TrueNAS."
grep -qE '^PANCAKE_CACHE_PATH=/mnt/' "$ENV_EXAMPLE" \
    || fail "PANCAKE_CACHE_PATH should be under /mnt on TrueNAS."
ok "Data and cache mounts are configured."

# 6. Required environment variables
echo "[6/10] Checking required environment variables..."
for var in TZ ORCA_WEB_MAX_JOBS ORCA_WEB_PRINTER_NETWORK PANCAKE_STAGE_CACHE_MAX_MB ORCA_WEB_BEARER_TOKEN ORCA_WEB_TRUSTED_PROXIES; do
    grep -qE "^[[:space:]]+${var}:" "$TEMPLATE_FILE" \
        || fail "Missing environment variable $var in $TEMPLATE_FILE."
done
ok "Required environment variables are present."

# 7. Container hardening
echo "[7/10] Checking container hardening..."
grep -qF 'no-new-privileges:true' "$TEMPLATE_FILE" \
    || fail "Missing security_opt no-new-privileges:true."
CAP_DROP_BLOCK="$(sed -n '/cap_drop:/,/^[[:space:]]*[a-z]/p' "$TEMPLATE_FILE")"
printf '%s\n' "$CAP_DROP_BLOCK" | grep -q -- '- ALL' \
    || fail "cap_drop must drop ALL capabilities."
grep -qF 'memory: "${PANCAKE_MEMORY_LIMIT}"' "$TEMPLATE_FILE" \
    || fail "Missing the deploy memory limit."
if grep -qE '^[[:space:]]*privileged:[[:space:]]*true' "$TEMPLATE_FILE"; then
    fail "privileged: true is not allowed."
fi
if grep -qF '/var/run/docker.sock' "$TEMPLATE_FILE"; then
    fail "Mounting the Docker socket is not allowed."
fi
if grep -qE '^[[:space:]]*network_mode:[[:space:]]*host' "$TEMPLATE_FILE"; then
    fail "The default template must use bridge networking."
fi
ok "Container hardening checks passed."

# 8. Legacy placeholders
echo "[8/10] Checking for legacy placeholders..."
if grep -rqE '__[A-Z_]+__' compose/ 2>/dev/null; then
    fail "Legacy __PLACEHOLDER__ syntax found in compose/."
fi
ok "No legacy placeholders found."

# 9. Documentation set
echo "[9/10] Checking documentation set..."
for doc in \
    docs/installation.md \
    docs/configuration.md \
    docs/storage.md \
    docs/networking.md \
    docs/printers.md \
    docs/reverse-proxy.md \
    docs/upgrades.md \
    docs/backup-restore.md \
    docs/troubleshooting.md \
    truenas/README.md; do
    [ -f "$doc" ] || fail "Missing documentation file: $doc"
done
ok "Documentation set is complete."

# 10. Secret leakage
echo "[10/10] Running secret leakage check..."
./scripts/check-secrets.sh

echo "--- Validation Successful ---"
