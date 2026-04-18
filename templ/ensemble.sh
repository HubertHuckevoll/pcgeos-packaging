#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ENSEMBLE_DIR="$SCRIPT_DIR"
USER_CONFIG_FILE="${ENSEMBLE_DIR}/basebox.conf"
BASEBOX_VERSION="${BASEBOX_VERSION:-{{BASEBOX_VERSION}}}"
BASEBOX_RAISE_WINDOW="${BASEBOX_RAISE_WINDOW:-auto}"

focus_basebox_window() {
    if [ "$BASEBOX_RAISE_WINDOW" = "0" ]; then
        return
    fi

    if [ "$BASEBOX_RAISE_WINDOW" = "auto" ]; then
        if [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
            BASEBOX_RAISE_WINDOW="1"
        else
            BASEBOX_RAISE_WINDOW="0"
        fi
    fi

    if [ "$BASEBOX_RAISE_WINDOW" != "1" ]; then
        return
    fi

    (
        BASEBOX_TRIES=0
        while [ "$BASEBOX_TRIES" -lt 25 ]; do
            BASEBOX_TRIES=$((BASEBOX_TRIES + 1))

            if command -v xdotool >/dev/null 2>&1; then
                BASEBOX_WIN_ID="$(xdotool search --onlyvisible --class dosbox-staging 2>/dev/null | tail -n 1 || true)"
                if [ -n "$BASEBOX_WIN_ID" ]; then
                    xdotool windowactivate "$BASEBOX_WIN_ID" >/dev/null 2>&1 || true
                    xdotool windowraise "$BASEBOX_WIN_ID" >/dev/null 2>&1 || true
                    exit 0
                fi
            fi

            if command -v wmctrl >/dev/null 2>&1; then
                wmctrl -a "DOSBox" >/dev/null 2>&1 && exit 0
                wmctrl -x -a org.dosbox-staging.dosbox-staging.org.dosbox-staging.dosbox-staging >/dev/null 2>&1 && exit 0
            fi

            sleep 0.2
        done
    ) >/dev/null 2>&1 &
}

start_basebox_detached() {
    if command -v systemd-run >/dev/null 2>&1; then
        BASEBOX_SYSTEMD_UNIT="ensemble-basebox-$$-$(date +%s)"
        if systemd-run --user --quiet --collect --unit "$BASEBOX_SYSTEMD_UNIT" \
            --working-directory="$ENSEMBLE_DIR" \
            --property=KillMode=process \
            --setenv=DISPLAY="${DISPLAY:-}" \
            --setenv=WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-}" \
            --setenv=XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-}" \
            --setenv=XDG_SESSION_TYPE="${XDG_SESSION_TYPE:-}" \
            -- "$BASEBOX_EXEC" -noprimaryconf -nolocalconf -conf "$USER_CONFIG_FILE" "$@"; then
            return 0
        fi
    fi

    if command -v nohup >/dev/null 2>&1; then
        if command -v setsid >/dev/null 2>&1; then
            nohup setsid "$BASEBOX_EXEC" -noprimaryconf -nolocalconf -conf "$USER_CONFIG_FILE" "$@" </dev/null >/dev/null 2>&1 &
        else
            nohup "$BASEBOX_EXEC" -noprimaryconf -nolocalconf -conf "$USER_CONFIG_FILE" "$@" </dev/null >/dev/null 2>&1 &
        fi
    elif command -v setsid >/dev/null 2>&1; then
        setsid "$BASEBOX_EXEC" -noprimaryconf -nolocalconf -conf "$USER_CONFIG_FILE" "$@" </dev/null >/dev/null 2>&1 &
    else
        "$BASEBOX_EXEC" -noprimaryconf -nolocalconf -conf "$USER_CONFIG_FILE" "$@" </dev/null >/dev/null 2>&1 &
    fi

    return 0
}

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
BASEBOX_CONSOLE_MODE_DEFAULT="{{BASEBOX_CONSOLE_MODE_UNIX}}"
BASEBOX_CONSOLE_MODE="${BASEBOX_CONSOLE_MODE:-$BASEBOX_CONSOLE_MODE_DEFAULT}"

cd "$ENSEMBLE_DIR"

if [ ! -x "$BASEBOX_EXEC" ]; then
    printf 'Error: Expected Basebox executable not found at %s\n' "$BASEBOX_EXEC" >&2
    exit 1
fi

if [ "$BASEBOX_CONSOLE_MODE" = "hide" ]; then
    start_basebox_detached "$@"
    focus_basebox_window
    exit 0
fi

exec "$BASEBOX_EXEC" -noprimaryconf -nolocalconf -conf "$USER_CONFIG_FILE" "$@"
