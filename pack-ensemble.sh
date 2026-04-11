#!/usr/bin/env bash
set -euo pipefail

GEOS_ZIP_URL="${GEOS_ZIP_URL:-https://github.com/bluewaysw/pcgeos/releases/download/CI-latest/pcgeos-ensemble_nc.zip}"
BASEBOX_ZIP_URL="${BASEBOX_ZIP_URL:-https://github.com/bluewaysw/pcgeos-basebox/releases/download/CI-latest-issue-13/pcgeos-basebox.zip}"
OUTPUT_NAME="${OUTPUT_NAME:-ensemble.zip}"
OUTPUT_DIR="${OUTPUT_DIR:-$PWD/packaged}"
BASEBOX_CONSOLE_MODE="${BASEBOX_CONSOLE_MODE:-hide}"
BASEBOX_VERSION="${BASEBOX_VERSION:-10}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TOP_LEVEL_LAUNCHERS=(
    ensemble.sh
    ensemble.cmd
)

VERSION_LAUNCHERS=(
    ensemble.sh
    ensemble.cmd
)

EXPECTED_BASEBOX_BINARIES=(
    binl64/basebox
    binmac/basebox
    binrpi64/basebox
    binnt/basebox.exe
    binnt64/basebox.exe
)

DOWNLOADER=""
TEMPLATE_DIR_RESOLVED=""
TMP_ROOT=""
GEOS_ZIP_PATH=""
BASEBOX_ZIP_PATH=""
GEOS_EXTRACT_DIR=""
BASEBOX_EXTRACT_DIR=""
STAGED_ENSEMBLE_DIR=""
STAGED_BASEBOX_DIR=""
OUTPUT_ZIP_PATH=""
LOADER_DIR_DOS=""
BASEBOX_CONSOLE_ARG_WIN=""
BASEBOX_CONSOLE_ARG_UNIX_SUFFIX=""

progress() {
    printf '[pack-ensemble] %s\n' "$1"
}

cleanup() {
    progress 'cleanup'
    if [[ -n "$TMP_ROOT" && -d "$TMP_ROOT" ]]; then
        rm -rf "$TMP_ROOT"
    fi
}

die() {
    progress 'die'
    printf 'Error: %s\n' "$1" >&2
    exit 1
}

require_cmd() {
    progress "require_cmd: $1"
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1 || die "Required command not found: $cmd"
}

select_downloader() {
    progress 'select_downloader'
    if command -v curl >/dev/null 2>&1; then
        DOWNLOADER="curl"
        return
    fi

    if command -v wget >/dev/null 2>&1; then
        DOWNLOADER="wget"
        return
    fi

    die 'Need either curl or wget for downloads.'
}

check_required_tools() {
    progress 'check_required_tools'
    local cmd
    for cmd in unzip zip find awk sed; do
        require_cmd "$cmd"
    done
    select_downloader
}

clean_output_dir() {
    progress 'clean_output_dir'

    if [[ -z "$OUTPUT_DIR" || "$OUTPUT_DIR" == "/" ]]; then
        die "Refusing to clean unsafe OUTPUT_DIR value: '$OUTPUT_DIR'"
    fi

    rm -rf "$OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR"
}

resolve_template_dir() {
    progress 'resolve_template_dir'
    local candidate
    local -a candidates=()

    if [[ -n "${TEMPLATE_DIR:-}" ]]; then
        candidates+=("$TEMPLATE_DIR")
    fi

    candidates+=(
        "$SCRIPT_DIR/templ"
        "$SCRIPT_DIR/../templ"
        "$PWD/templ"
        "/app/templ"
    )

    for candidate in "${candidates[@]}"; do
        if [[ -f "$candidate/basebox.conf" && -f "$candidate/ensemble.sh" && -f "$candidate/basebox-version.sh" ]]; then
            TEMPLATE_DIR_RESOLVED="$candidate"
            return
        fi
    done

    die 'Could not find templates directory with basebox.conf and unified launcher templates.'
}

init_workspace() {
    progress 'init_workspace'
    TMP_ROOT="$(mktemp -d)"
    trap cleanup EXIT

    GEOS_ZIP_PATH="$TMP_ROOT/downloads/geos.zip"
    BASEBOX_ZIP_PATH="$TMP_ROOT/downloads/basebox.zip"
    GEOS_EXTRACT_DIR="$TMP_ROOT/extracted/geos"
    BASEBOX_EXTRACT_DIR="$TMP_ROOT/extracted/basebox"

    mkdir -p \
        "$(dirname "$GEOS_ZIP_PATH")" \
        "$(dirname "$BASEBOX_ZIP_PATH")" \
        "$GEOS_EXTRACT_DIR" \
        "$BASEBOX_EXTRACT_DIR"
}

download_file() {
    progress "download_file: $1"
    local url="$1"
    local destination="$2"

    if [[ "$DOWNLOADER" == "curl" ]]; then
        curl -fsSL --retry 3 --retry-delay 1 -o "$destination" "$url"
    else
        wget -q -O "$destination" "$url"
    fi
}

download_archives() {
    progress 'download_archives'
    download_file "$GEOS_ZIP_URL" "$GEOS_ZIP_PATH"
    download_file "$BASEBOX_ZIP_URL" "$BASEBOX_ZIP_PATH"
}

extract_archives() {
    progress 'extract_archives'
    unzip -q "$GEOS_ZIP_PATH" -d "$GEOS_EXTRACT_DIR"
    unzip -q "$BASEBOX_ZIP_PATH" -d "$BASEBOX_EXTRACT_DIR"

    [[ -d "$GEOS_EXTRACT_DIR/ensemble" ]] || die 'GEOS archive must contain top-level ensemble/ directory.'
    [[ -d "$BASEBOX_EXTRACT_DIR/pcgeos-basebox" ]] || die 'Basebox archive must contain top-level pcgeos-basebox/ directory.'
}

prepare_output_paths() {
    progress 'prepare_output_paths'
    STAGED_ENSEMBLE_DIR="$OUTPUT_DIR/ensemble"
    STAGED_BASEBOX_DIR="$STAGED_ENSEMBLE_DIR/basebox/$BASEBOX_VERSION"
    OUTPUT_ZIP_PATH="$OUTPUT_DIR/$OUTPUT_NAME"
}

stage_ensemble_tree() {
    progress 'stage_ensemble_tree'
    mkdir -p "$OUTPUT_DIR"
    rm -rf "$STAGED_ENSEMBLE_DIR"
    rm -f "$OUTPUT_ZIP_PATH"

    mv "$GEOS_EXTRACT_DIR/ensemble" "$STAGED_ENSEMBLE_DIR"
}

stage_basebox_tree() {
    progress 'stage_basebox_tree'
    local -a items=()

    mkdir -p "$STAGED_BASEBOX_DIR"

    shopt -s dotglob nullglob
    items=("$BASEBOX_EXTRACT_DIR/pcgeos-basebox"/*)
    shopt -u dotglob

    [[ "${#items[@]}" -gt 0 ]] || die 'Basebox archive has no files to stage.'

    mv "${items[@]}" "$STAGED_BASEBOX_DIR/"
    shopt -u nullglob
}

locate_loader_dir() {
    progress 'locate_loader_dir'
    local loader_path
    local loader_parent_abs
    local loader_parent_rel

    loader_path="$(find "$STAGED_ENSEMBLE_DIR" -type f -iname 'loader.exe' | sort | awk 'NR==1 { print; exit }')"
    [[ -n "$loader_path" ]] || die 'loader.exe not found in staged ensemble tree.'

    loader_parent_abs="$(dirname "$loader_path")"
    if [[ "$loader_parent_abs" == "$STAGED_ENSEMBLE_DIR" ]]; then
        LOADER_DIR_DOS='ensemble'
        return
    fi

    loader_parent_rel="${loader_parent_abs#"$STAGED_ENSEMBLE_DIR"/}"

    # basebox.conf [autoexec] uses DOS-style separators.
    LOADER_DIR_DOS="ensemble\\$(printf '%s' "$loader_parent_rel" | sed 's#/#\\\\#g')"
}

generate_basebox_conf() {
    progress 'generate_basebox_conf'
    # Mount the parent directory so DOS C: contains the ensemble folder.
    sed \
        -e 's|{{HOST_PATH}}|..|g' \
        -e "s|{{LOADER_DIR}}|$LOADER_DIR_DOS|g" \
        "$TEMPLATE_DIR_RESOLVED/basebox.conf" > "$STAGED_ENSEMBLE_DIR/basebox.conf"
}

resolve_basebox_console_arg() {
    progress 'resolve_basebox_console_arg'
    case "${BASEBOX_CONSOLE_MODE,,}" in
        show)
            BASEBOX_CONSOLE_ARG_WIN=""
            BASEBOX_CONSOLE_ARG_UNIX_SUFFIX=""
            ;;
        hide)
            BASEBOX_CONSOLE_ARG_WIN="-noconsole"
            BASEBOX_CONSOLE_ARG_UNIX_SUFFIX=">/dev/null 2>&1 &"
            ;;
        *)
            printf "Warning: Invalid BASEBOX_CONSOLE_MODE '%s'; falling back to 'hide' (expected: show or hide)\n" "$BASEBOX_CONSOLE_MODE" >&2
            BASEBOX_CONSOLE_ARG_WIN="-noconsole"
            BASEBOX_CONSOLE_ARG_UNIX_SUFFIX=">/dev/null 2>&1 &"
            ;;
    esac
}

escape_sed_replacement() {
    printf '%s' "$1" | sed 's/[\\|&]/\\&/g'
}

install_launchers() {
    progress 'install_launchers'
    local escaped_console_arg_win
    local escaped_console_arg_unix_suffix

    escaped_console_arg_win="$(escape_sed_replacement "$BASEBOX_CONSOLE_ARG_WIN")"
    escaped_console_arg_unix_suffix="$(escape_sed_replacement "$BASEBOX_CONSOLE_ARG_UNIX_SUFFIX")"

    cp "$TEMPLATE_DIR_RESOLVED/ensemble.sh" "$STAGED_ENSEMBLE_DIR/ensemble.sh"
    cp "$TEMPLATE_DIR_RESOLVED/ensemble.cmd" "$STAGED_ENSEMBLE_DIR/ensemble.cmd"

    sed \
        -e "s|{{BASEBOX_CONSOLE_ARG_UNIX_SUFFIX}}|$escaped_console_arg_unix_suffix|g" \
        "$TEMPLATE_DIR_RESOLVED/basebox-version.sh" > "$STAGED_BASEBOX_DIR/ensemble.sh"

    sed \
        -e "s|{{BASEBOX_CONSOLE_ARG_WIN}}|$escaped_console_arg_win|g" \
        "$TEMPLATE_DIR_RESOLVED/basebox-version.cmd" > "$STAGED_BASEBOX_DIR/ensemble.cmd"

    printf '%s\n' "$BASEBOX_VERSION" > "$STAGED_ENSEMBLE_DIR/basebox/version.txt"

    chmod +x "$STAGED_ENSEMBLE_DIR/ensemble.sh" "$STAGED_BASEBOX_DIR/ensemble.sh"
}

validate_basebox_binaries() {
    progress 'validate_basebox_binaries'
    local rel
    local expected

    for rel in "${EXPECTED_BASEBOX_BINARIES[@]}"; do
        expected="$STAGED_BASEBOX_DIR/$rel"
        [[ -f "$expected" ]] || die "Missing expected Basebox binary: $expected"
    done
}

check_no_absolute_path_leaks() {
    progress 'check_no_absolute_path_leaks'
    local file
    local -a generated_files=()

    generated_files+=("$STAGED_ENSEMBLE_DIR/basebox.conf")
    generated_files+=("$STAGED_ENSEMBLE_DIR/basebox/version.txt")

    for file in "${TOP_LEVEL_LAUNCHERS[@]}"; do
        generated_files+=("$STAGED_ENSEMBLE_DIR/$file")
    done

    for file in "${VERSION_LAUNCHERS[@]}"; do
        generated_files+=("$STAGED_BASEBOX_DIR/$file")
    done

    for file in "${generated_files[@]}"; do
        if awk -v p1="$TMP_ROOT" -v p2="$PWD" -v p3="$OUTPUT_DIR" 'index($0,p1) || index($0,p2) || index($0,p3) { found=1 } END { exit found ? 0 : 1 }' "$file"; then
            die "Absolute build path leaked into generated file: $file"
        fi
    done
}

build_archive() {
    progress 'build_archive'
    (
        cd "$OUTPUT_DIR"
        zip -qr "$OUTPUT_NAME" ensemble
    )
}

verify_zip_layout() {
    progress 'verify_zip_layout'
    unzip -Z1 "$OUTPUT_ZIP_PATH" | awk '$0 !~ /^ensemble\// { bad=1 } END { exit bad ? 1 : 0 }' \
        || die 'ZIP layout invalid; expected top-level ensemble/.'
}

print_success() {
    progress 'print_success'
    printf 'Created %s\n' "$OUTPUT_ZIP_PATH"
}

main() {
    progress 'main'
    clean_output_dir
    check_required_tools
    resolve_template_dir
    init_workspace
    download_archives
    extract_archives
    prepare_output_paths
    stage_ensemble_tree
    stage_basebox_tree
    locate_loader_dir
    generate_basebox_conf
    resolve_basebox_console_arg
    install_launchers
    validate_basebox_binaries
    check_no_absolute_path_leaks
    build_archive
    verify_zip_layout
    print_success
}

main "$@"
