#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${PACK_ENSEMBLE_CONFIG:-$SCRIPT_DIR/pack-ensemble.conf}"

if [[ ! -f "$CONFIG_FILE" ]]; then
    printf 'Error: Required config file not found: %s\n' "$CONFIG_FILE" >&2
    exit 1
fi

source "$CONFIG_FILE"

BUILD_VARIANTS=()

REQUIRED_VARIANTS=(
    "regular|$GEOS_ZIP_URL|$OUTPUT_DIR"
)

OPTIONAL_VARIANTS=(
    "german|$GEOS_GERMAN_ZIP_URL|$OUTPUT_DIR/german"
)

TOP_LEVEL_LAUNCHERS=(
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
TMP_WORK_ROOT=""
TMP_ROOT=""
GEOS_ZIP_PATH=""
BASEBOX_ZIP_PATH=""
GEOS_EXTRACT_DIR=""
BASEBOX_EXTRACT_DIR=""
STAGED_ENSEMBLE_DIR=""
STAGED_BASEBOX_DIR=""
OUTPUT_ZIP_PATH=""
VARIANT_OUTPUT_DIR=""
BASEBOX_CONSOLE_ARG_WIN=""
BASEBOX_CONSOLE_ARG_UNIX_SUFFIX=""
BUILT_ARCHIVES=()

progress() {
    printf '[pack-ensemble] %s\n' "$1"
}

cleanup() {
    progress 'cleanup'
    if [[ -n "$TMP_WORK_ROOT" && -d "$TMP_WORK_ROOT" ]]; then
        rm -rf "$TMP_WORK_ROOT"
    elif [[ -n "$TMP_ROOT" && -d "$TMP_ROOT" ]]; then
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
        if [[ -f "$candidate/basebox.conf" && -f "$candidate/ensemble.sh" && -f "$candidate/ensemble.cmd" ]]; then
            TEMPLATE_DIR_RESOLVED="$candidate"
            return
        fi
    done

    die 'Could not find templates directory with basebox.conf and ensemble launcher templates.'
}

init_workspace() {
    progress "init_workspace: $1"
    local variant_key="$1"

    if [[ -z "$TMP_WORK_ROOT" ]]; then
        TMP_WORK_ROOT="$(mktemp -d)"
        trap cleanup EXIT
    fi

    TMP_ROOT="$TMP_WORK_ROOT/$variant_key"
    rm -rf "$TMP_ROOT"

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
    local geos_zip_url="$1"

    download_file "$geos_zip_url" "$GEOS_ZIP_PATH"
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
    progress "prepare_output_paths: $1"
    local variant_output_dir="$1"

    VARIANT_OUTPUT_DIR="$variant_output_dir"
    STAGED_ENSEMBLE_DIR="$VARIANT_OUTPUT_DIR/ensemble"
    STAGED_BASEBOX_DIR="$STAGED_ENSEMBLE_DIR/basebox/$BASEBOX_VERSION"
    OUTPUT_ZIP_PATH="$VARIANT_OUTPUT_DIR/$OUTPUT_NAME"
}

stage_ensemble_tree() {
    progress 'stage_ensemble_tree'
    mkdir -p "$VARIANT_OUTPUT_DIR"
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

generate_basebox_conf() {
    progress 'generate_basebox_conf'
    # Mount the parent directory so DOS C: contains the ensemble folder.
    sed \
        -e 's|{{HOST_PATH}}|..|g' \
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

resolve_build_variants() {
    progress 'resolve_build_variants'

    BUILD_VARIANTS=("${REQUIRED_VARIANTS[@]}")

    case "${BUILD_OPTIONAL_VARIANTS,,}" in
        yes|true|1)
            BUILD_VARIANTS+=("${OPTIONAL_VARIANTS[@]}")
            ;;
        no|false|0)
            ;;
        *)
            die "Invalid BUILD_OPTIONAL_VARIANTS '$BUILD_OPTIONAL_VARIANTS' (expected: yes/no/true/false/1/0)"
            ;;
    esac
}

cleanup_staged_ensemble_tree() {
    progress 'cleanup_staged_ensemble_tree'
    case "${DELETE_STAGED_ENSEMBLE_DIRS,,}" in
        yes|true|1)
            rm -rf "$STAGED_ENSEMBLE_DIR"
            ;;
        no|false|0)
            ;;
        *)
            die "Invalid DELETE_STAGED_ENSEMBLE_DIRS '$DELETE_STAGED_ENSEMBLE_DIRS' (expected: yes/no/true/false/1/0)"
            ;;
    esac
}

escape_sed_replacement() {
    printf '%s' "$1" | sed 's/[\\|&]/\\&/g'
}

install_launchers() {
    progress 'install_launchers'
    local escaped_basebox_version
    local escaped_console_arg_win
    local escaped_console_arg_unix_suffix

    escaped_basebox_version="$(escape_sed_replacement "$BASEBOX_VERSION")"
    escaped_console_arg_win="$(escape_sed_replacement "$BASEBOX_CONSOLE_ARG_WIN")"
    escaped_console_arg_unix_suffix="$(escape_sed_replacement "$BASEBOX_CONSOLE_ARG_UNIX_SUFFIX")"

    sed \
        -e "s|{{BASEBOX_VERSION}}|$escaped_basebox_version|g" \
        -e "s|{{BASEBOX_CONSOLE_ARG_UNIX_SUFFIX}}|$escaped_console_arg_unix_suffix|g" \
        "$TEMPLATE_DIR_RESOLVED/ensemble.sh" > "$STAGED_ENSEMBLE_DIR/ensemble.sh"

    sed \
        -e "s|{{BASEBOX_VERSION}}|$escaped_basebox_version|g" \
        -e "s|{{BASEBOX_CONSOLE_ARG_WIN}}|$escaped_console_arg_win|g" \
        "$TEMPLATE_DIR_RESOLVED/ensemble.cmd" > "$STAGED_ENSEMBLE_DIR/ensemble.cmd"

    chmod +x "$STAGED_ENSEMBLE_DIR/ensemble.sh"
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

    for file in "${TOP_LEVEL_LAUNCHERS[@]}"; do
        generated_files+=("$STAGED_ENSEMBLE_DIR/$file")
    done

    for file in "${generated_files[@]}"; do
        if awk -v p1="$TMP_ROOT" -v p2="$PWD" -v p3="$VARIANT_OUTPUT_DIR" -v p4="$OUTPUT_DIR" 'index($0,p1) || index($0,p2) || index($0,p3) || index($0,p4) { found=1 } END { exit found ? 0 : 1 }' "$file"; then
            die "Absolute build path leaked into generated file: $file"
        fi
    done
}

build_archive() {
    progress 'build_archive'
    (
        cd "$VARIANT_OUTPUT_DIR"
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
    local archive_path

    for archive_path in "${BUILT_ARCHIVES[@]}"; do
        printf 'Created %s\n' "$archive_path"
    done
}

build_variant() {
    progress "build_variant: $1"
    local variant_key="$1"
    local geos_zip_url="$2"
    local variant_output_dir="$3"

    init_workspace "$variant_key"
    download_archives "$geos_zip_url"
    extract_archives
    prepare_output_paths "$variant_output_dir"
    stage_ensemble_tree
    stage_basebox_tree
    generate_basebox_conf
    install_launchers
    validate_basebox_binaries
    check_no_absolute_path_leaks
    build_archive
    verify_zip_layout
    cleanup_staged_ensemble_tree
    BUILT_ARCHIVES+=("$OUTPUT_ZIP_PATH")
}

main() {
    progress 'main'
    local variant_spec
    local variant_key
    local geos_zip_url
    local variant_output_dir

    clean_output_dir
    check_required_tools
    resolve_template_dir
    resolve_basebox_console_arg
    resolve_build_variants

    for variant_spec in "${BUILD_VARIANTS[@]}"; do
        IFS='|' read -r variant_key geos_zip_url variant_output_dir <<< "$variant_spec"

        [[ -n "$variant_key" ]] || die "Invalid variant key in BUILD_VARIANTS entry: $variant_spec"
        [[ -n "$geos_zip_url" ]] || die "Missing GEOS URL for variant '$variant_key'"
        [[ -n "$variant_output_dir" ]] || die "Missing output directory for variant '$variant_key'"

        build_variant "$variant_key" "$geos_zip_url" "$variant_output_dir"
    done

    [[ "${#BUILT_ARCHIVES[@]}" -gt 0 ]] || die 'No archives were built.'

    print_success
}

main "$@"
