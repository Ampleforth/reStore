#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
: "${GO:=go}"
: "${RCC:=/usr/lib/qt6/rcc}"
restore_arch="${RESTORE_ARCH:-${CARCH:-armv7}}"
case "$restore_arch" in
    armv7) restore_goarch=arm; restore_goarm=7 ;;
    aarch64) restore_goarch=arm64; restore_goarm= ;;
    *) echo "Unsupported architecture: $restore_arch (expected armv7 or aarch64)" >&2; exit 1 ;;
esac
restore_bundle="dist/$restore_arch/archive-books"
"$GO" test ./...
python3 -m unittest discover -s tests -p 'test_*.py'
mkdir -p "$restore_bundle/backend"
CGO_ENABLED=0 GOOS=linux GOARCH="$restore_goarch" GOARM="$restore_goarm" "$GO" build -trimpath -ldflags='-s -w' -o "$restore_bundle/backend/entry" .
"$RCC" --binary --format-version 3 --no-compress packaging/application.qrc -o "$restore_bundle/resources.rcc"
cp packaging/manifest.json LICENSE LICENSE.upstream.md THIRD_PARTY_NOTICES.md "$restore_bundle/"
mkdir -p "$restore_bundle/licenses"
cp qml/fonts/LICENSE-DejaVu.txt qml/fonts/LICENSE-Noto.txt "$restore_bundle/licenses/"
cp "$("$GO" env GOROOT)/LICENSE" "$restore_bundle/licenses/Go-BSD-3-Clause.txt"
rsvg-convert -w 64 -h 64 qml/books.svg -o "$restore_bundle/icon.png"
cp README.md "$restore_bundle/"
if [ ! -x "$restore_bundle/runtime/usr/lib/chromium/chromium" ]; then
    python3 scripts/build-runtime.py --arch "$restore_arch" --output "$restore_bundle/runtime" --cache "${RESTORE_RUNTIME_CACHE:-/tmp/restore-runtime-cache}"
fi
cp engine/server.py engine/parser.py "$restore_bundle/runtime/app/"
chmod 0644 "$restore_bundle/runtime/app/server.py" "$restore_bundle/runtime/app/parser.py" "$restore_bundle/resources.rcc"
python3 scripts/check-bundle.py --arch "$restore_arch"
if [[ "${RESTORE_ARCHIVE:-1}" != 0 ]]; then
    tar -czf "dist/restore-$restore_arch.tar.gz" -C "dist/$restore_arch" archive-books
fi
printf 'Built %s for %s.\n' "$restore_bundle" "$restore_arch"
