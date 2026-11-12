# Building and testing

## Host tools

Use Linux with Go 1.25 or later, Qt 6 `rcc`, `rsvg-convert`, Python 3.11 or later,
Beautiful Soup 4 and `bsdtar` (libarchive). No Go modules outside the standard
library are required. Runtime extraction does not install Debian packages into
host system directories or run their maintainer scripts.

```sh
./scripts/build.sh
```

The script tests the Go and Python code, cross-compiles a static Linux ARMv7
backend, compiles QML resources and assembles the private runtime. It checks the
runtime package lock, install permissions and absence of private runtime data
before creating `dist/restore-armv7.tar.gz`.

Optional paths:

```sh
GO=/path/to/go RCC=/usr/lib/qt6/libexec/rcc ./scripts/build.sh
```

Arch typically provides `/usr/lib/qt6/rcc`; Debian/Ubuntu toolchain images use
`/usr/lib/qt6/libexec/rcc`. Set `RESTORE_ARCHIVE=0` to skip the intermediate tar
when preparing a release or Vellum package.

## Runtime lock

`packaging/runtime.lock.json` pins the 147 Debian ARMhf packages in v0.1.0, with
versions, URLs and SHA-256 hashes. The runtime builder verifies every downloaded
package before extraction. It fetches only locked packages by default and caches
packages outside the source tree. The full runtime is approximately 400 MiB.

```sh
python3 scripts/build-runtime.py --output dist/archive-books/runtime
```

For a deliberate runtime update, assemble into a new output directory with
`--refresh`, review its `packages.json`, update the lock, and repeat hardware
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
