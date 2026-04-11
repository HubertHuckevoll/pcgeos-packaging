#!/usr/bin/env bash
set -euo pipefail

IMAGE_TAG="${IMAGE_TAG:-pcgeos-pack-ensemble:local}"
GEOS_ZIP_URL="${GEOS_ZIP_URL:-https://github.com/bluewaysw/pcgeos/releases/download/CI-latest/pcgeos-ensemble_nc.zip}"
BASEBOX_ZIP_URL="${BASEBOX_ZIP_URL:-https://github.com/bluewaysw/pcgeos-basebox/releases/download/CI-latest-issue-13/pcgeos-basebox.zip}"
OUTPUT_NAME="${OUTPUT_NAME:-ensemble.zip}"
OUTPUT_DIR="${OUTPUT_DIR:-/work/packaged}"
BASEBOX_CONSOLE_MODE="${BASEBOX_CONSOLE_MODE:-hide}"
BASEBOX_VERSION="${BASEBOX_VERSION:-10}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v docker >/dev/null 2>&1; then
    printf 'Error: docker command not found. Please install Docker first.\n' >&2
    exit 1
fi

if ! docker image inspect "$IMAGE_TAG" >/dev/null 2>&1; then
    printf 'Error: Docker image %s not found. Run ./docker-build.sh first.\n' "$IMAGE_TAG" >&2
    exit 1
fi

printf '[docker-run] Running image %s\n' "$IMAGE_TAG"
docker run --rm \
  -v "$SCRIPT_DIR:/work" \
  -e GEOS_ZIP_URL="$GEOS_ZIP_URL" \
  -e BASEBOX_ZIP_URL="$BASEBOX_ZIP_URL" \
  -e OUTPUT_NAME="$OUTPUT_NAME" \
  -e OUTPUT_DIR="$OUTPUT_DIR" \
  -e BASEBOX_CONSOLE_MODE="$BASEBOX_CONSOLE_MODE" \
  -e BASEBOX_VERSION="$BASEBOX_VERSION" \
  "$IMAGE_TAG"
printf '[docker-run] Done. Output expected at %s\n' "$OUTPUT_DIR/$OUTPUT_NAME"
