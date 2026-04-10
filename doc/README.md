# pack-ensemble

Dockerized packer that downloads the latest PC/GEOS ensemble and Basebox archives, merges them into one portable `ensemble/` tree, and creates `ensemble.zip`.

## Build

Run from the repository root:

```bash
docker build -f Dockerfile -t pcgeos-pack-ensemble .
```

## Run

```bash
docker run --rm \
  -v "$(pwd):/work" \
  -e GEOS_ZIP_URL="https://github.com/bluewaysw/pcgeos/releases/download/CI-latest/pcgeos-ensemble_nc.zip" \
  -e BASEBOX_ZIP_URL="https://github.com/bluewaysw/pcgeos-basebox/releases/download/CI-latest-issue-13/pcgeos-basebox.zip" \
  -e OUTPUT_NAME="ensemble.zip" \
  -e OUTPUT_DIR="/work/packaged" \
  pcgeos-pack-ensemble
```

Default output is `/work/packaged/ensemble.zip` (host: `./packaged/ensemble.zip`).

## Output Structure

After unzip, the archive root is exactly:

```text
ensemble/
```

Key paths inside:

```text
ensemble/
  basebox.conf
  basebox/10/
    binl64/basebox
    binmac/basebox
    binrpi64/basebox
    binnt/basebox.exe
    binnt64/basebox.exe
  loader.exe
  ensemble-l64.sh
  ensemble-mac.sh
  ensemble-rpi64.sh
  ensemble-nt.cmd
  ensemble-nt64.cmd
  ENSEMBLE.BAT
  GO.BAT
```

## Launchers

- `ensemble-l64.sh`: Linux x86_64 launcher.
- `ensemble-mac.sh`: macOS launcher.
- `ensemble-rpi64.sh`: Raspberry Pi Linux arm64 launcher.
- `ensemble-nt.cmd`: Windows x86 launcher.
- `ensemble-nt64.cmd`: Windows x64 launcher.
- `ENSEMBLE.BAT`: pure DOS launcher from upstream GEOS payload.
- `GO.BAT`: DOS compatibility alias from upstream GEOS payload.

## Troubleshooting

### Missing `loader.exe`

If packaging fails with a `loader.exe not found` error, the GEOS ZIP is malformed or has an unexpected directory layout. Confirm the archive contains `ensemble/loader.exe` (or another case variant under `ensemble/`).

### Missing Basebox binaries

If packaging fails with `Missing expected Basebox binary`, the Basebox ZIP did not include one or more required runtime binaries under `pcgeos-basebox/bin*`.

Expected files:

- `binl64/basebox`
- `binmac/basebox`
- `binrpi64/basebox`
- `binnt/basebox.exe`
- `binnt64/basebox.exe`

### Linux missing libraries

If a Linux launcher detects unresolved shared libraries, it stops before startup and prints:

- each missing `.so` filename
- one distro-specific install command (`apt-get`, `dnf`, `pacman`, or `zypper`)

Example:

```text
Error: Missing shared libraries required by /path/to/ensemble/basebox/10/binl64/basebox:
  - libX11.so.6
  - libpulse.so.0
Recommended install command (Debian/Ubuntu):
  sudo apt-get update && sudo apt-get install -y libasound2 libpulse0 libsamplerate0 libgbm1 libwayland-egl1 libwayland-client0 libwayland-cursor0 libxkbcommon0 libdecor-0-0 libx11-6 libxext6 libxrender1 libgl1
```

If `ldd` is not available, the launcher prints a warning and continues without preflight checks.

### Bad ZIP root layout

If unzip results in any top-level directory other than `ensemble/`, the package is invalid. The packer checks this and aborts when the archive root is not exactly `ensemble/`.
