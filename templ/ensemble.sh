#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION_FILE="${SCRIPT_DIR}/basebox/version.txt"
BASEBOX_VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"

VERSION_LAUNCHER="${SCRIPT_DIR}/basebox/${BASEBOX_VERSION}/ensemble.sh"
if [[ ! -x "$VERSION_LAUNCHER" ]]; then
    printf 'Error: Version launcher not found or not executable at %s\n' "$VERSION_LAUNCHER" >&2
    exit 1
fi

exec "$VERSION_LAUNCHER" "$@"
