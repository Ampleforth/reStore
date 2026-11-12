#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
export QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=generic QT_QUICK_BACKEND=software
: "${QML:=/usr/lib/qt6/bin/qml}"
for mode in home results book links countdown progress folders keyboard browser browser-keyboard; do
    "$QML" -I tests/qml/imports scripts/preview.qml -- "--$mode" --output "$PWD/docs/$mode.png"
done
rsvg-convert -w 512 -h 512 qml/books.svg -o docs/icon.png
