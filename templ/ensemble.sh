#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ENSEMBLE_DIR="$SCRIPT_DIR"
USER_CONFIG_FILE="${ENSEMBLE_DIR}/basebox.conf"
BASEBOX_VERSION="${BASEBOX_VERSION:-{{BASEBOX_VERSION}}}"
BASEBOX_RAISE_WINDOW="${BASEBOX_RAISE_WINDOW:-auto}"
LOG_FILE="${ENSEMBLE_DIR}/ensemble.log"

log_line() {
    printf '%s\n' "$1" >> "$LOG_FILE"
}

write_start_log() {
    LOG_TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S %z' 2>/dev/null || date)"

    if [ "$#" -gt 0 ]; then
        printf '[%s] start: %s %s\n' "$LOG_TIMESTAMP" "$0" "$*" > "$LOG_FILE"
    else
        printf '[%s] start: %s\n' "$LOG_TIMESTAMP" "$0" > "$LOG_FILE"
    fi
}

focus_basebox_window() {
    if [ "$BASEBOX_RAISE_WINDOW" = "auto" ]; then
        BASEBOX_RAISE_WINDOW="0"
        if [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
            BASEBOX_RAISE_WINDOW="1"
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
                if wmctrl -a "DOSBox" >/dev/null 2>&1; then
                    exit 0
                fi
                if wmctrl -x -a org.dosbox-staging.dosbox-staging.org.dosbox-staging.dosbox-staging >/dev/null 2>&1; then
                    exit 0
                fi
            fi

            sleep 0.2
        done
    ) >/dev/null 2>&1 &
}

launch_basebox_background() {
    BASEBOX_LAUNCH_MODE="$1"
    shift

    case "$BASEBOX_LAUNCH_MODE" in
        nohup+setsid)
            nohup setsid "$BASEBOX_EXEC" "$@" </dev/null >> "$LOG_FILE" 2>&1 &
            ;;
        nohup)
            nohup "$BASEBOX_EXEC" "$@" </dev/null >> "$LOG_FILE" 2>&1 &
            ;;
        setsid)
            setsid "$BASEBOX_EXEC" "$@" </dev/null >> "$LOG_FILE" 2>&1 &
            ;;
        *)
            "$BASEBOX_EXEC" "$@" </dev/null >> "$LOG_FILE" 2>&1 &
            ;;
    esac

    log_line "launch: $BASEBOX_LAUNCH_MODE pid=$!"
}

start_basebox_detached() {
    set -- -noprimaryconf -nolocalconf -conf "$USER_CONFIG_FILE" "$@"

    if command -v systemd-run >/dev/null 2>&1; then
        BASEBOX_SYSTEMD_UNIT="ensemble-basebox-$$-$(date +%s)"
        if systemd-run --user --quiet --collect --unit "$BASEBOX_SYSTEMD_UNIT" \
            --working-directory="$ENSEMBLE_DIR" \
            --property=KillMode=process \
            --property="StandardOutput=append:$LOG_FILE" \
            --property="StandardError=append:$LOG_FILE" \
            --setenv=DISPLAY="${DISPLAY:-}" \
            --setenv=WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-}" \
            --setenv=XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-}" \
            --setenv=XDG_SESSION_TYPE="${XDG_SESSION_TYPE:-}" \
            -- "$BASEBOX_EXEC" "$@"; then
            log_line "launch: systemd-run unit=$BASEBOX_SYSTEMD_UNIT"
            return 0
        fi
        log_line "launch: systemd-run failed, using nohup/setsid fallback"
    fi

    if command -v nohup >/dev/null 2>&1; then
        if command -v setsid >/dev/null 2>&1; then
            launch_basebox_background "nohup+setsid" "$@"
        else
            launch_basebox_background "nohup" "$@"
        fi
    elif command -v setsid >/dev/null 2>&1; then
        launch_basebox_background "setsid" "$@"
    else
        launch_basebox_background "background" "$@"
    fi

    return 0
}

resolve_basebox_binary() {
    OS_NAME="$(uname -s)"
    ARCH_NAME="$(uname -m)"

    case "$OS_NAME:$ARCH_NAME" in
        Darwin:*)
            BASEBOX_BIN_REL="binmac/basebox"
            ;;
        Linux:x86_64|Linux:amd64)
            BASEBOX_BIN_REL="binl64/basebox"
            ;;
        Linux:aarch64|Linux:arm64)
            BASEBOX_BIN_REL="binrpi64/basebox"
            ;;
        Linux:*)
            printf 'Error: Unsupported Linux architecture: %s\n' "$ARCH_NAME" >&2
            ;;
        *)
            printf 'Error: Unsupported platform for ensemble.sh: %s\n' "$OS_NAME" >&2
            ;;
    esac

    if [ -z "${BASEBOX_BIN_REL:-}" ]; then
        exit 1
    fi

    BASEBOX_EXEC="${ENSEMBLE_DIR}/basebox/${BASEBOX_VERSION}/${BASEBOX_BIN_REL}"
}

main() {
    resolve_basebox_binary
    cd "$ENSEMBLE_DIR"

    write_start_log "$@"
    log_line "basebox: $BASEBOX_EXEC"

    if [ ! -x "$BASEBOX_EXEC" ]; then
        log_line "error: missing executable $BASEBOX_EXEC"
        printf 'Error: Expected Basebox executable not found at %s\n' "$BASEBOX_EXEC" >&2
        exit 1
    fi

    start_basebox_detached "$@"
    log_line "launch: request submitted"
    focus_basebox_window
    log_line "launcher: exiting"
    exit 0
}

main "$@"
