#!/usr/bin/env bash
set -euo pipefail

IMAGE_TAG="${IMAGE_TAG:-pcgeos-pack-ensemble:local}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v docker >/dev/null 2>&1; then
    printf 'Error: docker command not found. Please install Docker first.\n' >&2
    exit 1
fi

printf '[docker-build] Building image %s\n' "$IMAGE_TAG"
docker build -f "$SCRIPT_DIR/Dockerfile" -t "$IMAGE_TAG" "$SCRIPT_DIR"
printf '[docker-build] Built image %s\n' "$IMAGE_TAG"
