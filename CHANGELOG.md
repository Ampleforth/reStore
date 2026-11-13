# Changelog

## 0.1.1

- Add native aarch64 backend and locked ARM64 browser runtime alongside ARMv7.
- Select builds from Vellum CARCH, isolate target outputs and reject mismatched
  backend/browser/Python ELF architectures and package locks.
- Generate separate ARMv7 and aarch64 binary release archives.
- Apply Vellum review feedback: explicit install calls, standard SOURCES format,
  remove the unnecessary runtime-copy comment and remove model-specific wording.
- Add bundled-runtime browser tests and architecture regression coverage.

## 0.1.0

Initial public release for reMarkable 2.

- Native EPUB/PDF search, grayscale covers, book metadata and slow-server dropdown.
- On-tablet Chromium with persistent cookies, interactive CAPTCHA view, automatic
  keyboard focus detection and continuation after accepted verification.
- Calendar-style keyboard, high-contrast controls, swipe scrolling, bottom browser
  crop while typing, and Done-to-search behavior.
- Server countdown, copy-only URL handling, byte progress and total percentages
  when available, PDF/EPUB content recognition and matching cached-file recovery.
- My files folder picker, validated native import and title-based filenames.
- Large home-screen donation message without a donation link.
- Idempotent unload cleanup and worker-readable install permissions.
- Source/binary release assets, runtime package lock, documentation, QML previews
  and a checksum-pinned Vellum recipe.
