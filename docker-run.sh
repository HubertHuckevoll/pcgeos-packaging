#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${PACK_ENSEMBLE_CONFIG:-$SCRIPT_DIR/pack-ensemble.conf}"

if [[ ! -f "$CONFIG_FILE" ]]; then
    printf 'Error: Required config file not found: %s\n' "$CONFIG_FILE" >&2
    exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG_FILE"

collect_config_var_names() {
    # Parse variable names from lines like: : "${VAR:=value}"
    sed -nE 's/^[[:space:]]*:[[:space:]]*"\$\{([A-Za-z_][A-Za-z0-9_]*)[:?=].*$/\1/p' "$CONFIG_FILE"
}

build_docker_env_args() {
    local var
    DOCKER_ENV_ARGS=()

    while IFS= read -r var; do
        [[ -n "$var" ]] || continue
        DOCKER_ENV_ARGS+=(-e "$var")
    done < <(collect_config_var_names)
}

if ! command -v docker >/dev/null 2>&1; then
    printf 'Error: docker command not found. Please install Docker first.\n' >&2
    exit 1
fi

if ! docker image inspect "$IMAGE_TAG" >/dev/null 2>&1; then
    printf 'Error: Docker image %s not found. Run ./docker-build.sh first.\n' "$IMAGE_TAG" >&2
    exit 1
fi

# Docker run should always use the container-facing output path from config.
OUTPUT_DIR="$DOCKER_OUTPUT_DIR"
build_docker_env_args

printf '[docker-run] Running image %s\n' "$IMAGE_TAG"
docker run --rm \
  -v "$SCRIPT_DIR:/work" \
  "${DOCKER_ENV_ARGS[@]}" \
  "$IMAGE_TAG"
printf '[docker-run] Done. Output expected at %s\n' "$OUTPUT_DIR/$OUTPUT_NAME"
