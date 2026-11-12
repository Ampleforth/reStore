# Troubleshooting

## A CAPTCHA keeps appearing

Complete each step the website requests. Use Continue if automatic continuation
has not recognized the next page. If a field does not open the keyboard, use the
Keyboard button. Changing networks changes the tablet's public IP and may cause
new verification. Cookies help retain a session; they do not guarantee fewer
challenges. Do not delete the browser profile as a routine update step.

## Download appears finished but no book is visible

Wait for **Added to library**, then check the folder selected in Settings. A
finished transfer is distinct from a completed native import. Use **Retry import**
if offered. A completed cached file may have been named `download` by the server;
v0.1.0 recognizes PDF/EPUB content and gives the imported file the book title.
Choosing the same edition and pressing Download can recover a matching cached
transfer without fetching it again.

If the server interrupted a transfer, returned HTML instead of a book, or supplied
an unsupported file, reStore reports an error. Choose another server. Files over
512 MiB are rejected. Do not rename an HTML error page to `.pdf`.

## The progress bar immediately reaches 100%

A matching cached download may have been reused. Small transfers can also finish
between status updates. Bytes and percentages come from the browser transfer,
not the site's catalog size estimate. An activity bar means the total is unknown.

## Browser exits with status 2 or reports Permission denied

Inspect the app's `runtime/engine.log`. `runtime/app/server.py` and `parser.py`
need mode 0644 so the unprivileged browser worker can read them; the backend
needs mode 0755. Release builds and the Vellum recipe enforce these permissions.
A private update made with a restrictive umask can accidentally remove access.
The browser runtime must contain the bundled ARMv7 binaries.

## The tablet UI reloads when closing

v0.1.0 removes repeated termination calls from the Close/destruction path.
If a reload recurs, record the time and collect the Xochitl journal and browser
log before making changes. A UI reload alone does not establish that the whole
tablet rebooted. This behavior still needs confirmation across firmware versions;
unit tests do not prove Xochitl/AppLoad unload behavior on hardware.

Do not reboot or restart Xochitl as a routine fix. Use a visible SSH session for
read-only diagnostics; share only redacted logs, never cookies, profiles or tokens.

## Search reports unrecognized markup

The site may have changed its HTML, returned an unavailable page or redirected to
verification. Preserve the error and report the reStore version, firmware version,
which step failed and whether verification was visible. No credentials or account
keys are needed for an issue report.
