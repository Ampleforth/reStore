#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
: "${GO:=go}"
: "${RCC:=/usr/lib/qt6/rcc}"
"$GO" test ./...
python3 -m unittest discover -s tests -p 'test_*.py'
mkdir -p dist/archive-books/backend
CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=7 "$GO" build -trimpath -ldflags='-s -w' -o dist/archive-books/backend/entry .
"$RCC" --binary --format-version 3 --no-compress packaging/application.qrc -o dist/archive-books/resources.rcc
cp packaging/manifest.json LICENSE LICENSE.upstream.md THIRD_PARTY_NOTICES.md dist/archive-books/
mkdir -p dist/archive-books/licenses
cp qml/fonts/LICENSE-DejaVu.txt qml/fonts/LICENSE-Noto.txt dist/archive-books/licenses/
cp "$("$GO" env GOROOT)/LICENSE" dist/archive-books/licenses/Go-BSD-3-Clause.txt
rsvg-convert -w 64 -h 64 qml/books.svg -o dist/archive-books/icon.png
cp README.md dist/archive-books/
if [ ! -x dist/archive-books/runtime/usr/lib/chromium/chromium ]; then
  python3 scripts/build-runtime.py
fi
cp engine/server.py engine/parser.py dist/archive-books/runtime/app/
# The worker drops to UID 65534 before Python opens these root-owned files.
chmod 0644 dist/archive-books/runtime/app/server.py dist/archive-books/runtime/app/parser.py dist/archive-books/resources.rcc
python3 scripts/check-bundle.py
if [[ "${RESTORE_ARCHIVE:-1}" != 0 ]]; then
    tar -czf dist/restore-armv7.tar.gz -C dist archive-books
fi

printf 'Built dist/archive-books/ for reMarkable 2 (ARMv7).\n'
