# reStore

Native book search and downloads for **reMarkable tablets**, built with AppLoad and XOVI.
Search Anna's Archive, choose an EPUB or PDF, and import it into a folder in your
reMarkable library. Search results and book details use a native, high-contrast
layout with grayscale covers. Everything runs on the tablet.

![reStore search results with multiple books and grayscale covers](docs/results.png)

## What it does

- Searches EPUB and PDF editions by title, author or ISBN. Keyboard **Done** starts
  the search.
- Shows covers, titles, authors, format, size and available publisher, language,
  year and page metadata. Missing page counts are marked unavailable.
- Lists slow download servers for guests, or fast servers after account login,
  in a dropdown above **Download**.
- Saves an optional secret key in Settings and signs in when the app opens.
  Key entry is visible while typing; the saved key is never displayed.
  Paid fast downloads remain subject to the account's membership and quota.
- Displays the site's countdown, transfer progress and received bytes. Files named
  simply `download` are recognized by their PDF/EPUB contents.
- Opens interactive verification on the tablet. Tap a CAPTCHA text field to open
  the keyboard; **Done** submits text. reStore continues automatically after it
  recognizes the accepted page. **Continue** is available as a fallback.
- Supports swipe scrolling and hold-then-drag CAPTCHA puzzles. Opening the keyboard
  preserves the bottom half of the browser image above it.
- Saves cookies between sessions and imports books using their titles into the
  folder selected under **Settings → Download books to**.
- Reuses a finished cached download when its MD5 matches the selected book.

The home screen first encourages readers to compensate authors by buying books,
supporting their work or requesting a library purchase. It then explains that
Anna's Archive membership donations provide fast downloads without a waitlist,
with tier-based daily limits, and how to use them with a secret key in reStore.
Some tiers offer reduced browser verification; CAPTCHAs can still appear in the
app. Both notices use centered headings, lighter body text and a bordered membership
panel, and can be scrolled on smaller screens.
reStore is independent of Anna's Archive.

Account support is included in v0.2.0. See the [account setup guide](docs/USER_GUIDE.md#use-a-paid-account).

## Requirements

| Item | Supported configuration |
|---|---|
| Architecture | ARMv7 (reMarkable 1/2) and aarch64 (newer tablets) |
| Device software | Developed and tested on 3.27.3.0, Qt 6.8.2 |
| Launcher | XOVI with AppLoad 0.5.3 or later |
| Connection | Tablet internet access; no companion computer/server during use |
| Storage | Roughly 400–550 MiB for the architecture-specific runtime, plus cookies, downloads and imported books |

The two architectures have separate native backends and Debian runtimes. Physical
device acceptance is confirmed on reMarkable 2; other models and firmware need
verification of native import, screen layout and memory use. The lower-memory
reMarkable 1 especially needs hardware testing. AppLoad and XOVI
are prerequisites and are not included in this package.

## Install

**Start with the [complete installation guide](docs/INSTALLATION.md)** for separate
Windows, macOS and Linux steps, prerequisites, checksum verification, first-time
setup, upgrades, backups and rollback. You do not need to build packages yourself.


Download `reStore-0.2.0-<architecture>.tar.gz` from the
[v0.2.0 release](https://github.com/Ampleforth/reStore/releases/tag/v0.2.0)
Choose `armv7` for reMarkable 1/2 or `aarch64` for newer tablets.
Verify it against the release's `SHA256SUMS`.

The archive contains `archive-books/`. Install that directory under
`/home/root/xovi/exthome/appload/`, then refresh AppLoad and open **reStore**.
The internal directory and application ID remain stable for existing users.

For an upgrade, close reStore first and replace the application files while
preserving `archive-books/runtime/state/` and the configuration directory.
A tablet reboot is not required. Do not overwrite a live browser profile.
See [installation and usage](docs/USER_GUIDE.md) for the full steps.

A [Vellum recipe](packaging/vellum/VELBUILD) is provided for submission to the
Vellum package repository. This does not mean reStore is already in its index.

## Screenshots

![Account settings with a masked saved key](docs/settings.png)


These are regenerated previews of the real QML interface with illustrative
metadata and covers, not photographs of live searches or CAPTCHAs.

| Screen | Preview |
|---|---|
| Home | [Author support, membership notice and search box](docs/home.png) |
| Results | [Multiple books and grayscale covers](docs/results.png) |
| Book | [Metadata and download button](docs/book.png) |
| Membership | [Fast download links](docs/fast.png) |
| Server selection | [Download link dropdown](docs/links.png) |
| Waiting | [Server countdown](docs/countdown.png) |
| Transfer | [Download progress](docs/progress.png) |
| Import | [Import destination and completed progress](docs/importing.png) |
| Account | [Secret-key settings](docs/settings.png) |
| Key entry | [Visible example key while typing](docs/account-keyboard.png) |
| Destination | [My files folder browser](docs/folders.png) |
| Search input | [Calendar-style keyboard](docs/keyboard.png) |
| Verification | [Browser and instructions](docs/browser.png) |
| Verification input | [Bottom of browser visible above keyboard](docs/browser-keyboard.png) |

[Preview cover attribution](docs/covers/SOURCES.md) · [App icon](docs/icon.png)

## Documentation

- [Usage, settings and upgrades](docs/USER_GUIDE.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Architecture and private data](docs/ARCHITECTURE.md)
- [Building, testing and preview generation](docs/BUILDING.md)
- [Release assets and Vellum packaging](docs/RELEASING.md)
- [Changelog](CHANGELOG.md)

## Development

```sh
./scripts/build.sh
./scripts/preview.sh
./scripts/release.sh
```

Build dependencies, exact outputs and optional tool paths are documented in
[BUILDING.md](docs/BUILDING.md). Runtime package versions and SHA-256 hashes are pinned separately in
`packaging/runtime.lock.json` (ARMv7) and `packaging/runtime.aarch64.lock.json`.

## License and credits

reStore application code is **GPL-3.0-only**. The keyboard and controls follow the
[Nextcloud Calendar app](https://github.com/Ampleforth/remarkable2-nextcloudCalendar).
The adapted MIT toolbar notice, font licenses, Go license and Debian runtime
notices are retained. See [third-party notices](THIRD_PARTY_NOTICES.md) and
[LICENSE](LICENSE). Firmware APIs and site markup can change; parser failures
are reported rather than replaced with invented book data.
