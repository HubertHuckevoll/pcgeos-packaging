#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${PACK_ENSEMBLE_CONFIG:-$SCRIPT_DIR/pack-ensemble.conf}"

if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

IMAGE_TAG="${IMAGE_TAG:-${IMAGE_TAG_DEFAULT:-pcgeos-pack-ensemble:local}}"

if ! command -v docker >/dev/null 2>&1; then
    printf 'Error: docker command not found. Please install Docker first.\n' >&2
    exit 1
fi

printf '[docker-build] Building image %s\n' "$IMAGE_TAG"
docker build -f "$SCRIPT_DIR/Dockerfile" -t "$IMAGE_TAG" "$SCRIPT_DIR"
printf '[docker-build] Built image %s\n' "$IMAGE_TAG"
