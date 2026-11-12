#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
RESTORE_ARCHIVE=0 ./scripts/build.sh
python3 scripts/release.py
