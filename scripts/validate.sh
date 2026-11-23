#!/usr/bin/env bash
set -euo pipefail

TEMPLATE_FILE="compose/compose.template.yaml"
RENDERED_FILE="build/compose.yaml"
ENV_EXAMPLE=".env.example"

# Ensure we are in the project root.
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
echo "[0/13] Checking shell script syntax..."
bash -n scripts/*.sh
ok "Shell scripts parse cleanly."

# 1. Template variables documented in .env.example
echo "[1/13] Checking template variables against $ENV_EXAMPLE..."
MISSING_VARS=0
while IFS= read -r var; do
    [ -z "$var" ] && continue
    if ! grep -qE "^${var}=" "$ENV_EXAMPLE"; then
        echo "FAIL: $var is used by the template but missing from $ENV_EXAMPLE."
        MISSING_VARS=1
    fi
done < <(grep -oE '\$\{[A-Z0-9_]+\}' "$TEMPLATE_FILE" | tr -d '${}' | sort -u)

if [ "$MISSING_VARS" -ne 0 ]; then
    fail "Template variables and $ENV_EXAMPLE are out of sync."
fi
ok "Every template variable is documented."

# 2. Compose structural validation
echo "[2/13] Validating Compose template and variables..."
COMPOSE_CMD=()
if command -v docker &> /dev/null && docker compose version &> /dev/null; then
    COMPOSE_CMD=(docker compose)
elif command -v docker-compose &> /dev/null; then
    COMPOSE_CMD=(docker-compose)
fi

if [ ${#COMPOSE_CMD[@]} -gt 0 ]; then
    "${COMPOSE_CMD[@]}" --env-file "$ENV_EXAMPLE" -f "$TEMPLATE_FILE" config >/dev/null
    ok "YAML and variables are valid."
else
    echo "WARN: docker compose not found; skipping structural YAML validation."
fi

# 3. Required service
echo "[3/13] Checking required service..."
grep -qE '^  pancakeslicer:$' "$TEMPLATE_FILE" \
    || fail "Service 'pancakeslicer' is missing from $TEMPLATE_FILE."
ok "Service 'pancakeslicer' is present."

# 4. Pinned image
echo "[4/13] Checking image pin..."
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

# 5. LAN port mapping
echo "[5/13] Checking LAN port mapping..."
grep -qF '${PANCAKE_PORT}:6868' "$TEMPLATE_FILE" \
    || fail "The template must map \${PANCAKE_PORT} to container port 6868."
grep -qE '^PANCAKE_PORT=[0-9]+$' "$ENV_EXAMPLE" \
    || fail "PANCAKE_PORT must be numeric in $ENV_EXAMPLE."
ok "Port mapping is correct."

# 6. Persistent storage
echo "[6/13] Checking persistent storage..."
grep -qF '${PANCAKE_DATA_PATH}:/data' "$TEMPLATE_FILE" \
    || fail "Missing the \${PANCAKE_DATA_PATH}:/data volume mapping."
grep -qF '${PANCAKE_CACHE_PATH}:/data/jobs/stage-cache' "$TEMPLATE_FILE" \
    || fail "Missing the \${PANCAKE_CACHE_PATH}:/data/jobs/stage-cache volume mapping."
grep -qE '^PANCAKE_DATA_PATH=/mnt/' "$ENV_EXAMPLE" \
    || fail "PANCAKE_DATA_PATH should be under /mnt on TrueNAS."
grep -qE '^PANCAKE_CACHE_PATH=/mnt/' "$ENV_EXAMPLE" \
    || fail "PANCAKE_CACHE_PATH should be under /mnt on TrueNAS."
ok "Data and cache mounts are configured."

# 7. Required environment variables
echo "[7/13] Checking required environment variables..."
for var in TZ ORCA_WEB_MAX_JOBS ORCA_WEB_PRINTER_NETWORK PANCAKE_STAGE_CACHE_MAX_MB ORCA_WEB_BEARER_TOKEN ORCA_WEB_TRUSTED_PROXIES; do
    grep -qE "^[[:space:]]+${var}:" "$TEMPLATE_FILE" \
        || fail "Missing environment variable $var in $TEMPLATE_FILE."
done
ok "Required environment variables are present."

# 8. Container hardening
echo "[8/13] Checking container hardening..."
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

# 9. TrueNAS portal
echo "[9/13] Checking the TrueNAS portal entry..."
grep -qE '^x-portals:' "$TEMPLATE_FILE" \
    || fail "Missing x-portals for the TrueNAS Open button."
grep -qE '^[[:space:]]+port: 6868$' "$TEMPLATE_FILE" \
    || fail "x-portals must point at the default port 6868."
grep -qF 'scheme: http' "$TEMPLATE_FILE" \
    || fail "x-portals must advertise the HTTP UI."
ok "TrueNAS portal entry is present."

# 10. Legacy placeholders
echo "[10/13] Checking for legacy placeholders..."
if grep -rqE '__[A-Z_]+__' compose/ 2>/dev/null; then
    fail "Legacy __PLACEHOLDER__ syntax found in compose/."
fi
ok "No legacy placeholders found."

# 11. Documentation and packaging files
echo "[11/13] Checking documentation and packaging files..."
for doc in \
    README.md \
    CHANGELOG.md \
    LICENSE \
    .env.example \
    docs/installation.md \
    docs/configuration.md \
    docs/storage.md \
    docs/networking.md \
    docs/printers.md \
    docs/reverse-proxy.md \
    docs/security.md \
    docs/usage.md \
    docs/upgrades.md \
    docs/backup-restore.md \
    docs/troubleshooting.md \
    config/filament/README.md \
    truenas/README.md \
    truenas/pancake-slicer.example.yaml; do
    [ -f "$doc" ] || fail "Missing documentation or packaging file: $doc"
done
for script in scripts/init-env.sh scripts/render-compose.sh scripts/validate.sh scripts/check-secrets.sh; do
    [ -f "$script" ] || fail "Missing script: $script"
done
grep -qF '[MIT License](LICENSE)' README.md \
    || fail "README.md must link to the MIT LICENSE."
ok "Documentation and packaging files are complete."

# 12. Custom filament profiles
echo "[12/13] Checking custom filament profiles..."
for profile in config/filament/*.json; do
    [ -e "$profile" ] || continue
    python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$profile" \
        || fail "$profile is not valid JSON."
    grep -qF '"filament_settings_id"' "$profile" \
        || fail "$profile is missing filament_settings_id."
    grep -qF '"inherits"' "$profile" \
        || fail "$profile is missing inherits."
    if [ "$(basename "$profile")" = "extrudr-greentec-pro.json" ]; then
        python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); values=d.get("enable_pressure_advance") or []; assert values and all(v == "1" for v in values), "enable_pressure_advance must be 1"' "$profile" \
            || fail "$profile must enable pressure advance."
    fi
done
ok "Custom filament profiles are valid."

# 13. Secret leakage
echo "[13/13] Running secret leakage check..."
./scripts/check-secrets.sh

echo "--- Validation Successful ---"
