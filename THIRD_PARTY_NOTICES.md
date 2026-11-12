# Third-party notices

reStore application code is GPL-3.0-only. Retained component notices apply to
those components; bundled Debian packages keep their individual licenses.

| Component | Source and notice |
|---|---|
| Calendar QML controls and keyboard | [Ampleforth/remarkable2-nextcloudCalendar](https://github.com/Ampleforth/remarkable2-nextcloudCalendar), GPL-3.0-only; source headers retained |
| Adapted toolbar by Nicko Guyer, 2026 | MIT, `LICENSE.upstream.md` |
| Go runtime and standard library | BSD-3-Clause, `licenses/Go-BSD-3-Clause.txt` in the binary bundle; [Go source distributions](https://go.dev/dl/) |
| DejaVu fonts | `qml/fonts/LICENSE-DejaVu.txt` |
| Noto Symbols font | SIL Open Font License, `qml/fonts/LICENSE-Noto.txt` |
| Chromium, ChromeDriver, Python, Beautiful Soup and runtime libraries | Debian Bookworm ARMhf packages, with exact versions, download URLs and SHA-256 hashes in `packaging/runtime.lock.json` and the bundle's `runtime/packages.json` |

Debian package copyright and license notices are retained under
`runtime/usr/share/doc/<package>/copyright`. Debian publishes corresponding
source packages through [Debian Sources](https://sources.debian.org/),
[the Debian archive](https://deb.debian.org/debian/pool/) and
[the security archive](https://security.debian.org/debian-security/pool/updates/).
Consult each package's copyright file for upstream source names and licenses.
When redistributing the bundled runtime, retain its notices and provide the
corresponding sources required by each package's license. The reStore source
archive contains reStore's source, not Chromium or the other Debian sources.

XOVI, AppLoad and the tablet's Qt/firmware are prerequisites, not bundled here.
Anna's Archive and book covers belong to their respective owners. reStore is
an independent app and does not claim official affiliation. Preview cover
attribution is in `docs/covers/SOURCES.md`; covers are illustrative documentation
assets and are not installed with the app.
