#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASEBOX_DIR="${SCRIPT_DIR}/basebox/10"
BASEBOX_EXEC="${BASEBOX_DIR}/binmac/basebox"
USER_CONFIG_FILE="${SCRIPT_DIR}/basebox.conf"

cd "$SCRIPT_DIR"

if [ ! -x "$BASEBOX_EXEC" ]; then
    printf 'Error: Expected Basebox executable not found at %s\n' "$BASEBOX_EXEC" >&2
    exit 1
fi

exec "$BASEBOX_EXEC" -noprimaryconf -nolocalconf -conf "$USER_CONFIG_FILE" "$@" {{BASEBOX_CONSOLE_ARG_UNIX_SUFFIX}}
