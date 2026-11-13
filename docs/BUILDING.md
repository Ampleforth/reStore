# Building and testing

## Host tools

Use Linux with Go 1.25 or later, Qt 6 `rcc`, `rsvg-convert`, Python 3.11 or later,
Beautiful Soup 4 and `bsdtar` (libarchive). No Go modules outside the standard
library are required. Runtime extraction does not install Debian packages into
host system directories or run their maintainer scripts.

```sh
RESTORE_ARCH=armv7 ./scripts/build.sh
RESTORE_ARCH=aarch64 ./scripts/build.sh
```

The script tests the Go and Python code, cross-compiles a static Linux backend for the selected architecture, compiles QML resources and assembles the private runtime. It checks the
runtime package lock, install permissions and absence of private runtime data
before creating `dist/restore-<architecture>.tar.gz`.

Optional paths:

```sh
GO=/path/to/go RCC=/usr/lib/qt6/libexec/rcc ./scripts/build.sh
```

Arch typically provides `/usr/lib/qt6/rcc`; Debian/Ubuntu toolchain images use
`/usr/lib/qt6/libexec/rcc`. Set `RESTORE_ARCHIVE=0` to skip the intermediate tar
when preparing a release or Vellum package.

## Runtime lock

`packaging/runtime.lock.json` pins the ARMhf packages;
`packaging/runtime.aarch64.lock.json` pins ARM64 packages. Both record
versions, URLs and SHA-256 hashes. The runtime builder verifies every downloaded
package before extraction. It fetches only locked packages by default and caches
packages outside the source tree. Runtimes occupy roughly 400–550 MiB depending on architecture.

```sh
python3 scripts/build-runtime.py --arch armv7
python3 scripts/build-runtime.py --arch aarch64
```

For a deliberate runtime update, assemble into a new output directory with
`--arch <architecture> --refresh --write-lock`, review its `packages.json` and
updated lock, and repeat hardware
acceptance testing. Refreshing is not part of a normal release. A vanished Debian
package URL must be resolved without silently accepting a different version or
checksum. Do not replace the lock with live browser state.

## Tests

```sh
go test -race ./...
python3 -m unittest discover -s tests -p 'test_*.py'
QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=generic QT_QUICK_BACKEND=software \
  /usr/lib/qt6/bin/qmltestrunner -input tests/qml -import tests/qml/imports
go build -o /tmp/restore-host .
python3 tests/lifecycle.py /tmp/restore-host
python3 tests/browser_smoke.py
```

QML tests need Qt Quick, Qt Test and Qt QML runtime modules. On Ubuntu these may
include `qt6-declarative-dev-tools`, `qml6-module-qtquick`,
`qml6-module-qtquick-window`, `qml6-module-qttest`,
`qml6-module-qtqml-workerscript` and `qml6-module-qtqml-models`.
The browser smoke test needs a matching desktop `chromium`/`chromedriver` pair.
It uses local controlled fixture pages, never downloads books from Anna's Archive,
and verifies cookies, slow links, countdowns, extensionless transfers, byte
progress, verification input and cross-origin text-field focus.

Hardware checks remain necessary for native importing, firmware compatibility,
real CAPTCHA interactions and closing without a tablet UI reload. Do not reboot
a user's tablet or restart Xochitl to run acceptance checks without permission.

## Regenerate documentation previews

```sh
./scripts/preview.sh
```

The script renders the actual QML through test-only AppLoad/import mocks at
1404×1872. It refreshes all ten screen images and the icon. Multiple sample books,
grayscale covers and illustrative metadata are supplied by `scripts/preview.qml`.
No live account, cookies or download cache are used. `docs/covers/SOURCES.md`
records cover attribution. Optional `QML=/path/to/qml` overrides the renderer.

## Release

```sh
./scripts/release.sh
```

See [RELEASING.md](RELEASING.md) for the source archive, binary archive, checksum
manifest and Vellum recipe. The GitHub workflow prepares downloadable workflow
artifacts; it does not create a public release, push commits or reboot a tablet.

## Architecture selection and runtime validation

`RESTORE_ARCH` accepts `armv7` or `aarch64`. If unset, the build uses Vellum's
`CARCH`, falling back to `armv7` for manual builds. It maps to Go `arm`/`GOARM=7`
or Go `arm64`, and to Debian `armhf` or `arm64`. Outputs live in
`dist/<architecture>/archive-books/` so the two targets cannot reuse each other's
runtime. An unsupported architecture fails instead of silently creating ARMv7.

The bundle checker verifies ELF machine/class for the backend, Chromium,
ChromeDriver and Python and compares the runtime against the selected lock.
The release script requires both complete bundles and creates two binary archives.
The browser versions may differ between Debian architectures; each is tested
against the same controlled fixture suite.

```sh
./scripts/runtime-smoke.sh aarch64
./scripts/runtime-smoke.sh armv7
```

These tests run the bundled Python, Chromium, ChromeDriver and libraries as UID
65534 in disposable Docker containers. A non-native target needs Docker/QEMU
binfmt support; the GitHub workflow configures this in its ephemeral ARMv7 test
runner. QEMU closed the ARMv7 Chromium renderer during session creation, so CI
uses explicit `--dependencies-only` coverage for that emulated target: backend
help, Python/SSL/Beautiful Soup and Chromium/ChromeDriver executable startup.
This does not claim an ARMv7 renderer test. Native aarch64 runs the full suite.
The script does not install an emulator on the host or touch a tablet.

`tests/runtime-runner/main.go` runs the full browser fixture against a real
architecture's installed runtime in a temporary private mount namespace. It
mounts private proc/dev/tmp, drops to UID 65534, uses temporary browser profiles,
and kills its child process group on exit. It neither replaces the installed app
nor restarts the UI. Build it for the target and transfer it with the three
fixture files (`engine/server.py`, `engine/parser.py`, `tests/browser_smoke.py`).
Run it as root through a visible device terminal:

```sh
./runner /home/root/xovi/exthome/appload/archive-books/runtime /path/to/fixtures parent
```

Do not run a second browser while the user's reStore browser is active; check
available memory first. The helper is a development tool, not installed by Vellum.

For v0.1.1 preparation, the full bundled-browser suite passed natively on an
ARM64 Linux host and its ARM64 CI runner, and on the reMarkable 2's installed
ARMv7 runtime using the private fixture runner. These checks cover browser
behavior and ABI compatibility; they do not prove native document import or
UI layout on a physical aarch64 tablet.
