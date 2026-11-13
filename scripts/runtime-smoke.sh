#!/usr/bin/env bash
# Run the bundled browser and dependencies in a disposable container, never a tablet.
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
restore_arch="${1:?usage: runtime-smoke.sh armv7|aarch64}"
case "$restore_arch" in
    armv7) restore_platform=linux/arm/v7 ;;
    aarch64) restore_platform=linux/arm64 ;;
    *) echo "Unsupported architecture: $restore_arch" >&2; exit 1 ;;
esac
python3 scripts/check-bundle.py --arch "$restore_arch"
restore_context=$(mktemp -d)
trap 'rm -rf "$restore_context"' EXIT
cp -a "dist/$restore_arch/archive-books/runtime/." "$restore_context/"
mkdir -p "$restore_context/tests"
cp tests/browser_smoke.py "$restore_context/tests/"
cat > "$restore_context/Dockerfile" <<'DOCKER'
FROM scratch
COPY . /
ENV PATH=/usr/bin:/bin PYTHONPATH=/app:/usr/lib/python3/dist-packages RESTORE_ISOLATED=1 RESTORE_CHROMIUM=/usr/lib/chromium/chromium HOME=/tmp
USER 65534:65534
ENTRYPOINT ["/usr/bin/python3.11", "/tests/browser_smoke.py"]
DOCKER
docker build --platform "$restore_platform" -t "restore-runtime-test:$restore_arch" "$restore_context"
docker run --rm --platform "$restore_platform" --cap-drop ALL --security-opt no-new-privileges --tmpfs /tmp:rw,mode=1777 "restore-runtime-test:$restore_arch"
