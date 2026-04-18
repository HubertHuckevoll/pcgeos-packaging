#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENSEMBLE_DIR="$SCRIPT_DIR"
USER_CONFIG_FILE="${ENSEMBLE_DIR}/basebox.conf"
BASEBOX_VERSION="${BASEBOX_VERSION:-{{BASEBOX_VERSION}}}"

OS_NAME="$(uname -s)"
ARCH_NAME="$(uname -m)"
BASEBOX_BIN_REL=""

case "$OS_NAME" in
    Darwin)
        BASEBOX_BIN_REL="binmac/basebox"
        ;;
    Linux)
        case "$ARCH_NAME" in
            x86_64|amd64)
                BASEBOX_BIN_REL="binl64/basebox"
                ;;
            aarch64|arm64)
                BASEBOX_BIN_REL="binrpi64/basebox"
                ;;
            *)
                printf 'Error: Unsupported Linux architecture: %s\n' "$ARCH_NAME" >&2
                exit 1
                ;;
        esac
        ;;
    *)
        printf 'Error: Unsupported platform for ensemble.sh: %s\n' "$OS_NAME" >&2
        exit 1
        ;;
esac

BASEBOX_EXEC="${ENSEMBLE_DIR}/basebox/${BASEBOX_VERSION}/${BASEBOX_BIN_REL}"

cd "$ENSEMBLE_DIR"

if [[ ! -x "$BASEBOX_EXEC" ]]; then
    printf 'Error: Expected Basebox executable not found at %s\n' "$BASEBOX_EXEC" >&2
    exit 1
fi

exec "$BASEBOX_EXEC" -noprimaryconf -nolocalconf -conf "$USER_CONFIG_FILE" "$@" {{BASEBOX_CONSOLE_ARG_UNIX_SUFFIX}}
