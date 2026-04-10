#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASEBOX_DIR="${SCRIPT_DIR}/basebox/10"
BASEBOX_EXEC="${BASEBOX_DIR}/binrpi64/basebox"
USER_CONFIG_FILE="${SCRIPT_DIR}/basebox.conf"

cd "$SCRIPT_DIR"

if [ ! -x "$BASEBOX_EXEC" ]; then
    printf 'Error: Expected Basebox executable not found at %s\n' "$BASEBOX_EXEC" >&2
    exit 1
fi

if command -v ldd >/dev/null 2>&1; then
    mapfile -t MISSING_LIBS < <(ldd "$BASEBOX_EXEC" 2>/dev/null | awk '/=> not found/ { print $1 }')

    if [ "${#MISSING_LIBS[@]}" -gt 0 ]; then
        printf 'Error: Missing shared libraries required by %s:\n' "$BASEBOX_EXEC" >&2
        for lib in "${MISSING_LIBS[@]}"; do
            printf '  - %s\n' "$lib" >&2
        done

        if command -v apt-get >/dev/null 2>&1; then
            printf 'Recommended install command (Debian/Ubuntu):\n' >&2
            printf '  sudo apt-get update && sudo apt-get install -y libasound2 libpulse0 libsamplerate0 libgbm1 libwayland-egl1 libwayland-client0 libwayland-cursor0 libxkbcommon0 libdecor-0-0 libx11-6 libxext6 libxrender1 libgl1\n' >&2
        elif command -v dnf >/dev/null 2>&1; then
            printf 'Recommended install command (Fedora/RHEL):\n' >&2
            printf '  sudo dnf install -y alsa-lib pulseaudio-libs libsamplerate mesa-libgbm wayland libxkbcommon libdecor libX11 libXext libXrender mesa-libGL\n' >&2
        elif command -v pacman >/dev/null 2>&1; then
            printf 'Recommended install command (Arch):\n' >&2
            printf '  sudo pacman -S --needed alsa-lib libpulse libsamplerate mesa wayland libxkbcommon libdecor libx11 libxext libxrender\n' >&2
        elif command -v zypper >/dev/null 2>&1; then
            printf 'Recommended install command (openSUSE):\n' >&2
            printf '  sudo zypper install -y alsa-lib libpulse0 libsamplerate0 libgbm1 libwayland-client0 libwayland-egl1 libxkbcommon0 libdecor0 libX11-6 libXext6 libXrender1 Mesa-libGL1\n' >&2
        else
            printf 'Install packages that provide the missing libraries listed above, then retry.\n' >&2
        fi

        exit 1
    fi
else
    printf 'Warning: ldd not found; skipping Linux dependency preflight.\n' >&2
fi

exec "$BASEBOX_EXEC" -noprimaryconf -nolocalconf -conf "$USER_CONFIG_FILE" "$@" {{BASEBOX_CONSOLE_ARG_UNIX_SUFFIX}}
