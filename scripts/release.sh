#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
for restore_arch in armv7 aarch64; do
    RESTORE_ARCH="$restore_arch" RESTORE_ARCHIVE=0 ./scripts/build.sh
done
python3 scripts/release.py
