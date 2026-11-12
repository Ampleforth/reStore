# Release and Vellum packaging

The initial repository is `Ampleforth/reStore`, version `0.1.0`. Release preparation
is local; publishing the repository/tag/assets is a separate action.

## Prepare assets

1. Set `VERSION` and update `CHANGELOG.md` and the versioned links in README.
2. Regenerate previews with `./scripts/preview.sh` and review the images.
3. Run the tests in BUILDING.md, then `./scripts/release.sh`.
4. Inspect `dist/release/SHA256SUMS` and verify with
   `sha256sum -c SHA256SUMS` from that directory.

| Asset | Purpose |
|---|---|
| `reStore-0.1.0-source.tar.gz` | Allowlisted reStore source under `reStore-0.1.0/`, including docs, tests, fonts and runtime lock |
| `reStore-0.1.0-armv7.tar.gz` | Installable `archive-books/`, including the static backend, QML resources and private Debian runtime |
| `VELBUILD` | Generated, checksum-pinned Vellum recipe |
| `SHA256SUMS` | SHA-256 checksums of the three assets above |

The archives use normalized ownership/timestamps. Source inputs are explicitly
allowlisted; `.git`, `dist`, Python caches, local configuration, tokens, logs and
browser profiles are excluded. Runtime checks refuse nonempty private state or
mountpoint directories. This is not a copy of a live tablet installation.

The binary archive contains Debian binaries with their individual notices. Keep
those notices and make the corresponding source distributions available as
required when publishing or redistributing them; see THIRD_PARTY_NOTICES.md.
The reStore source asset is the app's source, not a source distribution for all
bundled third-party packages.

## Vellum recipe

`packaging/vellum/VELBUILD.in` is the editable recipe template. The release script
fills its version and SHA-512 checksum, writes `packaging/vellum/VELBUILD`, and
copies that result into the release assets. No `SKIP` checksum is used.

The recipe downloads the **release source asset**, not GitHub's automatically
created tag archive. The source archive excludes the generated VELBUILD to avoid
a self-referential checksum, but includes its template and generator. Re-running
release preparation regenerates the recipe from the resulting source archive.
Any source edit after generation requires generating the assets again.

The recipe follows the supplied
[calendar reference commit](https://github.com/Ampleforth/vellum/commit/21475104e53ab6b3f797d68c1466bb6e0b54928c):
ARMv7, the Golang toolchain image, a Debian Qt `rcc` path, explicit file modes and
license notices under `/home/root/.vellum/licenses/restore/`. It also carries
`rm2` compatibility and `!check !fhs !strip` options used by the calendar package.
The source build runs its own Go/Python checks and verifies locked Debian package
hashes. Runtime symlinks and executable modes are retained. No reboot, service
restart, system-root write or postinstall script is included.

The application installs at
`/home/root/xovi/exthome/appload/archive-books/` so existing users keep their
application identity and profile. The release's runtime state is empty and is
not package-owned user data. Vellum upgrades should be performed with reStore
closed. Native import, fonts and download recovery still need device acceptance
after a firmware or runtime change.

For a Vellum submission, place the generated `VELBUILD` in
`packages/restore/VELBUILD` in a Vellum checkout and use that repository's lint and
build tools. The source release URL must exist before a remote Vellum build can
fetch it. Local recipe package staging can be tested before publication, but it
is not a signed APK or an upstream acceptance test.

Vellum's contribution rules require a person to open its issues and PRs and to
write their descriptions. This repository only prepares the recipe; it does not
submit to Vellum. See [Vellum contributing](https://github.com/vellum-dev/vellum#contributing).

## Prepare the GitHub repository

This project lives inside a larger working directory. Do not push that parent
repository or unrelated projects. The release source asset contains the intended
standalone project contents and can be extracted to a separate directory for
initialization. Also copy the generated `packaging/vellum/VELBUILD` into that
checkout. Do not add `dist/` or private tablet files to Git.

Push the reviewed source to `https://github.com/Ampleforth/reStore`, create tag
`v0.1.0`, and attach the four files in `dist/release/` to the GitHub release. The
checked-in workflow can prepare fresh assets for a tag or manual invocation; it
uploads a workflow artifact and does not publish automatically. Preserve the
exact source asset referenced by the Vellum checksum.
