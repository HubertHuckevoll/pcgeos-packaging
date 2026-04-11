#!/usr/bin/env bash
set -euo pipefail

# Top-level dispatcher: this bundle is pinned to one basebox version.
BASEBOX_VERSION="{{BASEBOX_VERSION}}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export BASEBOX_VERSION
exec "${SCRIPT_DIR}/basebox/${BASEBOX_VERSION}/ensemble.sh" "$@"
