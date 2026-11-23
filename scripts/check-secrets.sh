#!/usr/bin/env bash
set -euo pipefail

# Ensure we are in the project root
cd "$(dirname "$0")/.."

echo "Checking for accidental secrets..."

EXIT_CODE=0

scan_files() {
    local pattern="$1"
    # Scan the working tree, excluding private/generated files and this script
    # (whose patterns would otherwise match themselves).
    find . -type f \
        -not -path './.git/*' \
        -not -path './.idea/*' \
        -not -path './build/*' \
        -not -name '.env' \
        -not -name '.env.local' \
        -not -name '.env.production' \
        -not -name 'secrets.env' \
        -not -name '*.log' \
        -not -name '*.secret' \
        -not -name 'check-secrets.sh' \
        -exec grep -IlE "$pattern" {} + 2>/dev/null || true
}

check_pattern() {
    local pattern="$1"
    local description="$2"
    local files
    files="$(scan_files "$pattern")"
    if [ -n "$files" ]; then
        echo "FAIL: $description"
        printf '%s\n' "$files" | sed 's/^/  - /'
        EXIT_CODE=1
    fi
}

# Non-empty bearer tokens committed anywhere in the working tree.
check_pattern 'PANCAKE_BEARER_TOKEN=[^$[:space:]]+' \
    "A non-empty PANCAKE_BEARER_TOKEN is present in a file."
check_pattern 'ORCA_WEB_BEARER_TOKEN:[[:space:]]*"?[^$"[:space:]]+' \
    "A non-empty ORCA_WEB_BEARER_TOKEN is present in a file."

# PEM-encoded private keys.
check_pattern 'BEGIN [A-Z ]*PRIVATE KEY' \
    "A PEM private key is present in a file."

# Files that must never be tracked by git.
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    for file in .env .env.local .env.production secrets.env build/compose.yaml; do
        if git ls-files --error-unmatch "$file" >/dev/null 2>&1; then
            echo "FAIL: $file is tracked by git and must stay ignored."
            EXIT_CODE=1
        fi
    done
fi

if [ "$EXIT_CODE" -eq 0 ]; then
    echo "OK: No obvious secrets found."
else
    echo "Secrets check FAILED. Remove the values or files before committing."
fi

exit "$EXIT_CODE"
