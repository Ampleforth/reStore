# Changelog

## 0.2.0

- Show finishing/import progress with the destination folder, retain the completed
  transfer bar, and separate background status polling from the UI busy state to
  stop Book details and other controls flashing on every progress refresh.
- Show the secret key while typing in the keyboard so entry can be checked for
  typos; keep the draft masked in Settings and never display the saved key.
- Put author support first on the home screen, followed by a donation notice
  explaining membership fast downloads and how to use them in reStore. Keep both
  notices readable with centered headings, lighter body text and a bordered
  membership panel, and allow scrolling on smaller screens.
- Replace generic JSON parse failures with endpoint/status diagnostics, return
  JSON for unknown API routes and briefly retry startup settings reads when the
  local backend is unavailable.
- Add a masked account secret-key field, private persistence, startup login,
  cookie-session reuse, retry and removal controls.
- Resume login through the existing CAPTCHA view, including verification after
  form submission, and sanitize sign-in errors to avoid exposing keys.
- Show fast download links after confirmed login and keep slow links for guests
  and failed logins. Membership and download quotas remain enforced by the site.
- Cover account switching, invalid keys, login challenges and direct fast transfers
  with the bundled Chromium integration fixture.

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
