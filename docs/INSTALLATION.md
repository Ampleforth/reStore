# Install reStore: Windows, macOS and Linux

This guide installs **reStore 0.2.0 on your reMarkable tablet**. Your computer is
used only to transfer the files. After installation, searches, CAPTCHA checks,
downloads and importing all run on the tablet. You do **not** need a companion
server, Python, Chromium, Go, Docker or a compiler on your computer.

If you already have reStore, follow [Upgrading](#upgrading-an-existing-installation)
instead of the fresh-install commands. Keep reStore closed during any update.

## Choose your installation route

| Situation | Route |
|---|---|
| reStore appears in your Vellum/reManager package index | Use the package-manager route below |
| reStore is not in the index yet | Use the manual release route in this guide |
| You want to develop or compile the app yourself | See [BUILDING.md](BUILDING.md); ordinary users do not need this |

A Vellum PR being open or approved does not by itself make the package available.
The package needs to be merged, built and published into the package index.
**Until then, use the release archives.**

## 1. Before you begin

You need:

- A reMarkable tablet with SSH access and internet access over Wi-Fi.
- XOVI and AppLoad **0.5.3 or later**, working on your tablet's firmware.
- A Windows, macOS or Linux computer, and either a USB data cable or a working
  Wi-Fi connection between the computer and tablet.
- Enough free tablet storage. Allow at least **1 GiB free for a fresh install**;
  an upgrade with a full backup can require **2 GiB or more**, depending on cached
  downloads. The installed runtime itself is roughly 400–550 MiB.
- The tablet's SSH password, entered by you into your terminal when prompted.
  This is different from an Anna's Archive secret key.

The app builds for ARMv7 and aarch64. Physical acceptance testing has used
reMarkable 2 with firmware 3.27.3.0 and Qt 6.8.2. Other devices and firmware still
need hardware testing of native import, layout and memory use. ARMv7 builds do
not mean the lower-memory reMarkable 1 has been fully tested.

### SSH access and Developer Mode

1. On reMarkable 1/2, look under **Settings → Help → Copyrights and licenses** for
   SSH login information. Labels can vary by firmware.
2. Models that require Developer Mode must have it enabled before SSH access.
   Read reMarkable's [Developer Mode instructions](https://developer.remarkable.com/documentation/developer-mode)
   and [support guide](https://support.remarkable.com/s/article/Developer-mode)
   before changing modes. Enabling it can erase local device data, so complete
   the backup/sync steps in the official instructions first.
3. The SSH username is normally `root`. Use the password displayed by the tablet,
   not your reMarkable cloud-account password.
4. Connect the tablet using a USB data cable. Its usual USB address is
   `10.11.99.1`. For Wi-Fi, use the tablet's actual current IP address from your
   device/network information. An IP shown in someone else's example is not
   necessarily your tablet's IP.
5. If USB SSH is unavailable on your computer, try the tablet's Wi-Fi IP while
   both devices are on the same network. Guest Wi-Fi can block device-to-device
   connections.

### Install and verify XOVI/AppLoad first

If you already open other AppLoad apps on this firmware, skip to section 2.
Otherwise:

1. Read [XOVI installation](https://github.com/asivery/rm-xovi-extensions#to-install-xovi)
   and [AppLoad](https://github.com/asivery/rm-appload). AppLoad depends on
   `qt-resource-rebuilder`; use their current instructions for your firmware.
2. If using Vellum, follow the [Vellum installation guide](https://github.com/vellum-dev/vellum-cli#installation).
   Its bootstrap instructions and checksums can change; use the current upstream
   instructions instead of an old copied bootstrap command.
3. In the tablet's SSH shell, Vellum users can install the prerequisites with:

   ```sh
   vellum update
   vellum add xovi appload
   ```

4. Start/activate XOVI using its own instructions and confirm the AppLoad launcher
   is visible. Its initial activation may restart the tablet UI. Do this before
   installing reStore. This guide's reStore installation does not reboot or
   restart Xochitl.
5. For a manual prerequisite installation, choose the architecture-specific XOVI
   and AppLoad releases described in their documentation. Installing reStore's
   archive alone does not install either prerequisite.

Do not change system boot services to make XOVI persistent. Follow upstream's
supported startup method. Installing prerequisites is separate from installing
or updating reStore.

## 2. Find the tablet architecture

First open your computer's terminal:

- **Windows:** Start → type `PowerShell` → open Windows PowerShell or Terminal.
- **macOS:** Applications → Utilities → Terminal.
- **Linux:** Open your desktop's Terminal application.

Run this, replacing the address if you are using Wi-Fi:

```sh
ssh root@10.11.99.1
```

On the first connection, SSH asks whether you trust the host key. Verify this is
your tablet and compare the fingerprint through a trusted connection if available
before accepting. Type your tablet password when prompted. No characters appear
while typing a password; that is normal.

Once the prompt is the tablet's shell, run:

```sh
uname -m
df -h /home/root
```

Use the `uname` output to choose the download:

| Tablet output | Release file |
|---|---|
| `armv7l` | `reStore-0.2.0-armv7.tar.gz` |
| `aarch64` | `reStore-0.2.0-aarch64.tar.gz` |
| Anything else | Stop and check compatibility before installing |

Choose by the **tablet** architecture, not your computer's CPU. An Apple Silicon
Mac or ARM Windows laptop can still be used to install the ARMv7 tablet build.

Return to your computer's shell:

```sh
exit
```

## 3. Download the correct files

1. Open the [v0.2.0 release](https://github.com/Ampleforth/reStore/releases/tag/v0.2.0).
2. Expand **Assets** if necessary.
3. Download the matching `reStore-0.2.0-…tar.gz` from the table above.
4. Download `SHA256SUMS` from the **same release**.
5. Put both files in one folder, such as Downloads/reStore.
6. Keep the `.tar.gz` file intact. Do not unzip it on your computer. Extracting on
   the tablet preserves the Linux executable permissions and runtime symlinks.

The `-source.tar.gz` asset and GitHub's automatic **Source code (zip)** / **Source
code (tar.gz)** downloads are for developers. They are not installable app bundles.
The `VELBUILD` asset is a package recipe, not an app to open on the tablet.

## 4A. Windows: verify and transfer

These commands use PowerShell. Windows OpenSSH is available as an optional feature;
see [Microsoft's OpenSSH documentation](https://learn.microsoft.com/en-us/windows-server/administration/OpenSSH/openssh-overview).

1. Run `ssh -V`. If Windows says the command is unknown, search Windows Settings
   for **Optional features**, add **OpenSSH Client**, then reopen PowerShell.
   You do not need OpenSSH Server or Windows Subsystem for Linux.
2. Open the folder containing the downloads in File Explorer. Click its address
   bar, type `powershell`, and press Enter to open a terminal in that folder.
3. Set these values. Change `armv7` to `aarch64` if section 2 showed `aarch64`;
   replace the address when using Wi-Fi:

   ```powershell
   $Archive = "reStore-0.2.0-armv7.tar.gz"
   $TabletIP = "10.11.99.1"
   ```

4. Verify the file:

   ```powershell
   $ChecksumLine = Get-Content .\SHA256SUMS | Where-Object { $_.EndsWith("  $Archive") }
   if (-not $ChecksumLine) { throw "No matching checksum found. Check the filename and release." }
   $Expected = ($ChecksumLine -split '\s+')[0]
   $Actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $Archive).Hash
   if ($Actual -ne $Expected) { throw "Checksum mismatch. Stop and download the files again." }
   Write-Host "Checksum OK"
   ```

5. Only continue after **Checksum OK**. Copy the archive:

   ```powershell
   scp -O $Archive "root@${TabletIP}:/home/root/"
   ```

6. Enter the tablet password if prompted. Wait for the transfer to reach 100% and
   return to the PowerShell prompt.
7. Connect to the tablet:

   ```powershell
   ssh "root@$TabletIP"
   ```

8. Continue with section 5 for a fresh install, or the upgrade section if reStore
   is already installed.

`scp -O` uses the legacy SCP transfer protocol, which works on tablets that do not
provide an SFTP subsystem. If your `scp` does not recognize `-O`, update the OpenSSH
client or use an SCP-capable transfer client. Do not change the tablet's SSH server.

## 4B. macOS: verify and transfer

1. Open Terminal. macOS includes SSH and SCP; no Homebrew packages are required.
2. Enter `cd ` (including the space), drag the download folder from Finder into
   Terminal, and press Enter. This opens that folder in the terminal.
3. Check the archive against the corresponding line in the checksum file:

   ```sh
   shasum -a 256 reStore-0.2.0-armv7.tar.gz
   cat SHA256SUMS
   ```

   For an aarch64 tablet, substitute `reStore-0.2.0-aarch64.tar.gz`. The complete
   64-character hash printed by `shasum` must match the line for that exact file
   in `SHA256SUMS`. Stop and download again if it differs.
4. Transfer the same archive. Use your tablet's actual IP if not connected by USB:

   ```sh
   scp -O reStore-0.2.0-armv7.tar.gz root@10.11.99.1:/home/root/
   ```

5. Enter the tablet password if prompted. Wait until transfer finishes.
6. Connect to the tablet:

   ```sh
   ssh root@10.11.99.1
   ```

7. Continue with section 5 or the upgrade section.

If an older macOS SCP client rejects `-O`, its default may already use the legacy
SCP protocol. In that case retry the transfer without `-O`.

## 4C. Linux: verify and transfer

1. Open Terminal and change to the folder containing both downloads:

   ```sh
   cd ~/Downloads/reStore
   ```

   Use your actual folder if different.
2. Check that SSH is installed with `ssh -V`. If missing, use your distribution's
   package manager to install its OpenSSH client package (`openssh-client` on
   Debian/Ubuntu; `openssh-clients` on Fedora; `openssh` on Arch).
3. Verify the release file:

   ```sh
   sha256sum --ignore-missing -c SHA256SUMS
   ```

   The archive you downloaded must show **OK**. Missing assets can be ignored;
   a failed checksum for your archive cannot.
4. Transfer the verified archive:

   ```sh
   scp -O reStore-0.2.0-armv7.tar.gz root@10.11.99.1:/home/root/
   ```

   Substitute `aarch64` if appropriate, and replace the IP for Wi-Fi.
5. Enter the tablet password if prompted and wait until transfer finishes.
6. Connect to the tablet:

   ```sh
   ssh root@10.11.99.1
   ```

7. Continue with section 5 or the upgrade section.

## 5. Fresh installation: commands on the tablet

Everything in this section runs in the **tablet's SSH shell**, after connecting
from your computer. Close any running AppLoad application first.

1. Set the filename for the archive you actually transferred:

   ```sh
   restore_archive=/home/root/reStore-0.2.0-armv7.tar.gz
   ```

   For an aarch64 tablet, use `/home/root/reStore-0.2.0-aarch64.tar.gz`.
2. Confirm that the archive is there:

   ```sh
   ls -lh "$restore_archive"
   ```

3. Set the paths:

   ```sh
   restore_app=/home/root/xovi/exthome/appload/archive-books
   restore_stage=/home/root/.cache/reStore-install-0.2.0
   ```

4. Check whether this is really a fresh install:

   ```sh
   ls -ld "$restore_app"
   ```

   **No such file or directory** is expected for a fresh install. If it exists,
   stop here and use the upgrade section. Do not overwrite it or delete its state.
5. Extract into a staging directory:

   ```sh
   mkdir -p /home/root/.cache
   mkdir -m 700 "$restore_stage"
   tar -xzpf "$restore_archive" -C "$restore_stage"
   ```

   If `mkdir` reports that the staging directory already exists, stop and inspect
   the previous attempt instead of merging another extraction into it.
6. Install the directory only if the destination is still absent:

   ```sh
   mkdir -p /home/root/xovi/exthome/appload
   if [ -e "$restore_app" ]; then
       echo "Already installed. Use the upgrade instructions."
   else
       mv "$restore_stage/archive-books" "$restore_app"
   fi
   ```

7. Check the layout and executable permissions:

   ```sh
   ls -l "$restore_app/manifest.json" "$restore_app/resources.rcc" "$restore_app/backend/entry"
   ls -l "$restore_app/runtime/app/server.py" "$restore_app/runtime/app/parser.py"
   "$restore_app/backend/entry" -h
   ```

   The backend should be executable (`-rwxr-xr-x`). QML resources and both Python
   files should be readable (`-rw-r--r--`). The backend's `-h` command should show
   usage information; it does not start a browser or import books.
8. Leave the SSH session:

   ```sh
   exit
   ```

9. On the tablet, reopen or refresh AppLoad's launcher and choose **reStore**.
   If it is missing, use the troubleshooting section below. Installing this app
   does not require rebooting the tablet or restarting Xochitl.

The app folder is intentionally named `archive-books`, while its launcher name is
**reStore**. Keep this directory name when upgrading. Do not create an extra level
such as `archive-books/archive-books/manifest.json`.

## 6. First launch and optional paid account

1. Open reStore and tap the gear button.
2. Under **Download books to**, browse your reMarkable **My files** folders and
   select a destination. This is your document library, not the Linux filesystem.
3. A paid account is optional. For one, tap **Enter secret key**, type the key from
   your Anna's Archive account, press **Done**, then **Save and log in**.
4. The keyboard displays the key while typing so you can find typos. The draft in
   Settings is masked, and the app does not display the saved key afterward.
5. If a CAPTCHA appears, complete it yourself. reStore continues automatically
   when it recognizes the accepted page; **Continue** is the fallback.
6. After confirmed login, book details use **Fast downloads**. Active membership
   and download quotas still apply. Without login, the app uses slow links.
7. The app uses the website's account flow, not the paid JSON download API. Neither
   paid login nor a membership guarantees CAPTCHA-free searches in reStore.
8. Search for a book. Press keyboard **Done** to search, select an EPUB/PDF edition,
   choose a server, and press **Download**.
9. Wait through any server countdown. At 100%, the app may show **Finishing
   download…**, then **Importing into My files / …**. Wait for **Added to …** before
   closing the app. Completed transfer and completed import are separate steps.

The secret key is saved in an owner-readable file on the tablet, not encrypted:
`/home/root/.config/archive-books/config.json`. Never put this file, your browser
profile, cookies or account key in a public issue. See [USER_GUIDE.md](USER_GUIDE.md)
for the complete account and download behavior.

## Upgrading an existing installation

Use the same computer-specific download, checksum and transfer steps above for
the new archive. Then connect to the tablet with SSH. **Close reStore and wait for
any import to finish before continuing.** Do not replace a live browser profile.

1. Set these paths; select the archive matching your tablet:

   ```sh
   restore_archive=/home/root/reStore-0.2.0-armv7.tar.gz
   restore_app=/home/root/xovi/exthome/appload/archive-books
   restore_stage=/home/root/.cache/reStore-upgrade-0.2.0
   restore_backup=/home/root/.cache/reStore-backups/$(date +%Y%m%d-%H%M%S)
   ```

2. Check space and confirm the app is closed:

   ```sh
   df -h /home/root
   ps w | grep -E '[a]rchive-books/backend/entry|[p]ython3.11 /app/server.py|[c]hromedriver --port'
   ```

   If these show reStore's backend/browser processes, close the app and check
   again. Do not kill Xochitl or reboot to perform an ordinary app upgrade.
3. Back up the application, including its browser state, and the external config:

   ```sh
   umask 077
   mkdir -p "$restore_backup"
   tar -czf "$restore_backup/application.tar.gz" -C /home/root/xovi/exthome/appload archive-books
   if [ -d /home/root/.config/archive-books ]; then
       cp -a /home/root/.config/archive-books "$restore_backup/config"
   fi
   if [ -d /home/root/.local/share/archive-books ]; then
       cp -a /home/root/.local/share/archive-books "$restore_backup/import-staging"
   fi
   ```

   Stop if any backup command fails. These files can contain secrets; keep the
   backup private. Existing imported documents are in My files, separately from
   the app's cached downloads.
4. Extract the new archive:

   ```sh
   mkdir -m 700 "$restore_stage"
   tar -xzpf "$restore_archive" -C "$restore_stage"
   ```

5. Copy the existing cookie profile and cached downloads into the new runtime:

   ```sh
   if [ -d "$restore_app/runtime/state" ]; then
       cp -a "$restore_app/runtime/state/." "$restore_stage/archive-books/runtime/state/"
   fi
   ```

   Stop if copying fails. Do not delete your old state to work around a space error.
6. Switch installations while retaining the old app for rollback:

   ```sh
   mv "$restore_app" "$restore_backup/previous-app"
   mv "$restore_stage/archive-books" "$restore_app"
   ```

   Run the second command only after the first succeeds. If the second fails,
   restore the old app immediately with
   `mv "$restore_backup/previous-app" "$restore_app"`.
7. Check `"$restore_app/backend/entry" -h`, exit SSH, and reopen reStore. Confirm
   the home screen, destination folder and saved-account status. Do not use
   **Retry login** unless needed: an explicit retry can clear site cookies, while
   ordinary startup reuses the signed-in session.
8. Keep the backup until the new version works. You can then remove the downloaded
   archive, empty staging directories and your chosen old backup to reclaim space.
   Do not remove `runtime/state`, `.config/archive-books`, or import staging while
   troubleshooting an unfinished import.

If you manage reStore with Vellum, use Vellum for subsequent updates rather than
mixing manual and package-managed ownership of the same files.

## Install or update using Vellum/reManager

This route applies **after `restore` appears in the published index**.

1. Install/connect [reManager](https://github.com/rmitchellscott/reManager) or
   [Vellum](https://github.com/vellum-dev/vellum-cli) using its own documentation.
2. Refresh the package index. With the Vellum CLI, run on the tablet:

   ```sh
   vellum update
   vellum search restore
   ```

3. If `restore` is listed, install it:

   ```sh
   vellum add restore
   ```

   Vellum obtains the built tablet package and resolves prerequisites. End users
   do not compile it themselves. The recipe builds the Go backend and QML from
   source on the package builder; its browser dependencies are pinned Debian
   binaries.
4. In reManager, refresh the package list, find **restore/reStore**, and select
   its install action. Interface labels can change; refer to reManager's guide.
5. Keep reStore closed while updating it. Follow your package manager's update
   instructions, then reopen the app. No reboot is required by the reStore package.
6. If `restore` is absent, stop retrying that command and use the manual release
   route. An open PR or a GitHub release does not add it to the index automatically.

## Troubleshooting installation

| Symptom | What to check |
|---|---|
| `ssh` or `scp` not found | Install the OpenSSH client on your computer; Windows needs the Client optional feature |
| Connection timed out / no route | Correct IP, awake tablet, USB data cable, both devices on reachable networks, guest-network isolation |
| Permission denied when logging in | Username `root` and tablet SSH password; Developer Mode where required; not the cloud password |
| Host key changed | Confirm the device identity before accepting a replacement key; a mode change/reset can change keys |
| `subsystem request failed` during transfer | Retry using `scp -O` |
| SHA checksum differs | Stop; download the archive and SHA256SUMS from the same release again |
| `Exec format error` | Wrong tablet architecture; repeat `uname -m` and use the corresponding archive |
| App absent from AppLoad | XOVI/AppLoad active, compatible firmware, correct directory and manifest location; refresh/reopen the launcher |
| App opens but service cannot connect | Backend executable/readable, correct architecture, complete matching archive; capture the endpoint/status shown |
| Older `JSON.parse: Parse error` | Upgrade to 0.2.0 for useful endpoint/status diagnostics; see [TROUBLESHOOTING.md](TROUBLESHOOTING.md) |
| Worker exits with status 2 | Check readable Python files and `runtime/engine.log`; do not copy using a tool that drops permissions/symlinks |
| Not enough space | Check `df -h /home/root`; account for archives, old app, profile and backups; preserve unfinished downloads |
| Search or login asks for verification | Complete the CAPTCHA; this is independent of installation success |

For more help, open an [issue in reStore](https://github.com/Ampleforth/reStore/issues)
with the model, firmware, app version, exact message and action that caused it.
Screenshots should hide secret keys. Do not attach configuration, cookies,
profiles, authentication URLs or whole private backups.

## Uninstall and rollback

- With Vellum, close the app and run `vellum del restore`; follow the package
  manager's guidance for any retained user data. Imported books remain in My files.
- For a manual uninstall, close the app and remove only
  `/home/root/xovi/exthome/appload/archive-books`. This deletes the app's browser
  profile and cached downloads as well as the program. External configuration and
  staging remain under the paths given above; remove those only if intentionally
  deleting the saved key/settings and unfinished imports too.
- For a manual rollback, close the app, move the failed installation aside, and
  move your backup's `previous-app` back to the exact `archive-books` path. If
  needed, restore `config` to `.config/archive-books` and `import-staging` to
  `.local/share/archive-books`. Keep the failed copy until you verify the rollback.
  Restoring a backup returns its cookies/cache to their earlier state; it does not
  remove documents already imported into My files.
