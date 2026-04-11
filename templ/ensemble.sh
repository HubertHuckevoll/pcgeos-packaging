#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION_FILE="${SCRIPT_DIR}/basebox/version.txt"

if [[ ! -f "$VERSION_FILE" ]]; then
    printf 'Error: Basebox version file not found at %s\n' "$VERSION_FILE" >&2
    exit 1
fi

BASEBOX_VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"
if [[ -z "$BASEBOX_VERSION" ]]; then
    printf 'Error: Basebox version file is empty: %s\n' "$VERSION_FILE" >&2
    exit 1
fi

VERSION_LAUNCHER="${SCRIPT_DIR}/basebox/${BASEBOX_VERSION}/ensemble.sh"
if [[ ! -x "$VERSION_LAUNCHER" ]]; then
    printf 'Error: Version launcher not found or not executable at %s\n' "$VERSION_LAUNCHER" >&2
    exit 1
fi

exec "$VERSION_LAUNCHER" "$@"
