# Architecture and data

reStore uses native QML for search, results, book details, settings and progress.
It parses the site's HTML rather than displaying the whole site as the app UI.
A browser screenshot is shown only when interactive verification or an unknown
download page needs the user's attention.

| Component | Responsibility |
|---|---|
| QML frontend | Search, grayscale covers, keyboard, verification input and native document importer |
| Go backend | Loopback API, AppLoad lifecycle, destination folder metadata, file validation and import staging |
| Python worker | HTML parsing, browser session, countdowns, download events and verification screenshots |
| Chromium/ChromeDriver | Original website JavaScript, cookies, CAPTCHA interaction and transfers |

## Local runtime

Debian ARMhf (ARMv7) or ARM64 (aarch64) packages are extracted into the app's private `runtime/`. They are
not installed into `/usr` on the tablet. Chromium, ChromeDriver, Python, Beautiful
Soup and their libraries are bundled. Versions, URLs and SHA-256 hashes are in
the two architecture-specific files `packaging/runtime.lock.json` and
`packaging/runtime.aarch64.lock.json`, plus `runtime/packages.json` in the binary bundle.

The backend creates a private mount namespace and chroot, supplies its own proc,
dev and temporary mounts, then drops the browser worker to UID/GID 65534.
Chromium uses `--no-sandbox` within that unprivileged filesystem isolation.
The browser cannot traverse the tablet's document library or root home. The Go
backend retains the access needed to read folder metadata and stage imports.
The launcher uses a process group; it does not require PID/IPC namespaces.

The frontend API listens on `127.0.0.1:38767`, rejects web origins and requires
`X-ArchiveBooks-Request: app`. Internal browser endpoints use a random per-launch
token. Logs omit application URLs and queries, although browser diagnostics may
contain technical session information. Treat logs and browser state as private.

## Stored data

| Path | Contents |
|---|---|
| App `runtime/state/` | Browser profile, cookies, private token and download cache |
| App `runtime/engine.log` | Browser startup and worker diagnostics |
| `/home/root/.config/archive-books/config.json` | Selected library folder UUID |
| `/home/root/.local/share/archive-books/staging/` | Validated files awaiting native import |

The native `DocumentImporter.importFromUrls(urls, parentId)` imports validated
books into the selected folder. reStore reads library metadata but does not
write Xochitl document metadata files directly. Imported copies are acknowledged
before cached downloads are removed. Failed imports retain the staged file.
Browser restarts are not a durable download queue.

Persistent browser cookies are enabled, including third-party cookies needed by
some verification frames. All requests and files use the tablet's own network
connection. Search retains `check=1`. reStore does not solve CAPTCHAs or bypass
server countdowns. Paid-account secret-key login and fast links are not part of
v0.1.1.

## Exit and performance

Close uses the AppLoad unload callback, and cleanup is idempotent. The worker's
parent-pipe watchdog allows Chromium to close and save cookies before terminating
its process group. Neither rebooting the tablet nor restarting Xochitl is an app
operation.

Verification captures use JPEG. Polling pauses during typing and dragging; input
is queued while a capture is in flight, and the previous image remains visible
while the next loads. These reduce blank frames and capture overhead, but they
do not control website latency or e-ink refresh behavior.
