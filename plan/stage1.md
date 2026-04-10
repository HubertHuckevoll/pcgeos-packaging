Implement a packaging workflow that runs in Docker and produces one distributable `ensemble.zip` that users can unzip anywhere and launch directly on Linux, macOS, Windows, Raspberry Pi Linux, and pure DOS.

Create these files:

1. `Tools/pack-ensemble/pack-ensemble.sh`
2. `Tools/pack-ensemble/Dockerfile`
3. `Tools/pack-ensemble/README.md`

`pack-ensemble.sh` requirements:

* Use Bash with `set -euo pipefail`.
* Define top-level configuration variables:

  * `GEOS_ZIP_URL` (required)
  * `BASEBOX_ZIP_URL` (required)
  * `OUTPUT_NAME` (default: `ensemble.zip`)
  * `WORK_DIR` (optional temp/work location)
* Check required tools (`curl` or `wget`, `unzip`, `zip`, `find`, `awk`, `sed`).
* Download both ZIP files.
* Extract both archives into temp folders.
* Normalize roots so extra top-level archive folders are handled automatically.
* Create final staging tree with exactly:

  * `ensemble/freegeos/60beta/...` (from GEOS archive; preserve GEOS content)
  * `ensemble/basebox/10/...` (all Basebox files copied here)
* Locate `loader.exe` in the staged `ensemble` tree (case-insensitive search).

  * Derive its parent directory relative to `ensemble/`.
  * Fail with clear message if not found.
* Generate `ensemble/basebox/10/basebox.conf` containing:

  * mount host folder as drive C
  * `cd` into detected loader directory
  * run `loader`
  * exit on close
* Generate launchers in `ensemble/`:

  * `ensLin.sh` using `basebox/10/binl64/basebox`
  * `ensMac.sh` using `basebox/10/binmac/basebox`
  * `ensPi.sh` using `basebox/10/binrpi64/basebox`
  * `ensWin.cmd` using `basebox\10\binnt64\basebox.exe` with fallback to `binnt\basebox.exe`
  * `ensemble.bat` for pure DOS that changes to loader directory and runs `loader.exe` directly (no Basebox dependency)
* Shell launchers must pass:

  * `-noprimaryconf -nolocalconf -conf <path to basebox.conf>`
* Mark `*.sh` launchers executable.
* Produce final `ensemble.zip` with top-level folder `ensemble/`.
* Ensure no absolute build-machine paths are embedded in scripts/config.
* Print concise success output with location of created ZIP.

`Dockerfile` requirements:

* Use a small Linux base image.
* Install only required runtime packages (bash, coreutils/findutils, unzip, zip, curl or wget).
* Copy `pack-ensemble.sh` into image and set executable.
* Set entrypoint to run the script.
* Support host volume mounts so output ZIP is written outside container.

`README.md` requirements:

* Include build command: `docker build ...`
* Include run command with volume mount and env vars for both URLs.
* Document expected output structure after unzip.
* Document all launcher names and their target platform.
* Provide troubleshooting section for missing `loader.exe`, missing Basebox binaries, and bad ZIP root layout.

Acceptance criteria:

* Running the container with valid URLs produces `ensemble.zip`.
* Unzipped output contains all launchers:

  * `ensLin.sh`, `ensMac.sh`, `ensPi.sh`, `ensWin.cmd`, `ensemble.bat`
* `ensemble/basebox/10/basebox.conf` exists and points to detected loader directory.
* Package is relocatable: unzipping to a different folder still works.