# Using reStore

## Install or update

1. Install XOVI and AppLoad using their own instructions. This release builds for ARMv7 and aarch64. Hardware testing used
   reMarkable 2 firmware 3.27.3.0 and AppLoad 0.5.3.
2. Download the matching release archive (`armv7` for reMarkable 1/2;
   `aarch64` for newer models) and `SHA256SUMS`. On your computer, place them
   together and run `sha256sum --ignore-missing -c SHA256SUMS`.
3. Extract the archive. Its `archive-books` directory belongs under
   `/home/root/xovi/exthome/appload/` on the tablet. Use your usual visible SSH or
   file transfer workflow. Do not install it into the system root filesystem.
4. Refresh AppLoad's application list and open **reStore**.

For updates, close reStore first. Preserve `runtime/state/` inside the installed
app, `/home/root/.config/archive-books/` and
`/home/root/.local/share/archive-books/`. Replace application files from the new
archive. A clean release's empty `state` directory contains no user profile;
check your transfer tool's overwrite behavior before upgrading. No reboot or
Xochitl restart is part of the installation procedure.

## Choose where books go

Open the gear button, then **Download books to**. Browse **My files**, open the
folder you want and select it. These are your reMarkable library folders, not
Linux directories. The setting is retained between runs. If a selected folder
is deleted, choose another destination before downloading.

## Search and download

Tap the search box, type a title, author or ISBN, then press keyboard **Done**
or **Search**. Results contain EPUB and PDF editions only. Open a result to see
its metadata, choose a slow server in the dropdown, then press **Download**.

A countdown follows the website's timer. Once the server begins transferring,
the app shows a progress bar and received bytes. Percentages appear when the
server provides a total size. The activity bar does not estimate a percentage
when the total is unknown.

After transfer, reStore validates the file and asks the native importer to add it
to the chosen folder. The filename is based on the selected book's title plus
`.epub` or `.pdf`, with unsafe filename characters replaced. Wait for **Added to
library** before closing. Downloads are limited to 512 MiB per book.

If a previous attempt downloaded the same book but did not import it, choose that
edition and press Download again. A matching MD5 lets reStore reuse the finished
cached transfer. This can make the progress bar reach 100% immediately.

## Complete verification

The verification view uses the same on-tablet browser session as search and
downloading. Solve the website's CAPTCHA yourself. Tap an editable field to open
the keyboard automatically; **Keyboard** remains a manual fallback. **Done**
sends your text and Enter. Hide the keyboard to restore the full browser panel.

Swipe vertically to scroll. Hold before dragging a CAPTCHA puzzle so the gesture
is sent to the puzzle instead of scrolling. Keyboard opening halves the visible
browser panel and keeps the original bottom portion visible at the same scale.

Once the website accepts verification and a recognized page appears, reStore
resumes automatically. Use **Continue** if needed. If the page requires its own
Submit button or more challenges, complete those steps first. Cookies remain
enabled, but CAPTCHA frequency is controlled by the website.

## Remove

Remove the installed `archive-books` application directory after closing the app.
This removes its private browser profile and unimported cached downloads.
Imported documents remain in My files. Configuration and staged imports live in
the paths described in [ARCHITECTURE.md](ARCHITECTURE.md).
