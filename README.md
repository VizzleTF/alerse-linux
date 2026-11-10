<p align="center">
  <img src="https://raw.githubusercontent.com/VizzleTF/alerse/main/artwork/alerse_256.png" width="120" alt="The Alerse icon">
</p>

<h1 align="center">Alerse for Linux</h1>

<p align="center">The Linux build of Alerse, a sidebar browser for people moving from Arc.</p>

Linux builds of [Alerse](https://github.com/VizzleTF/alerse), an Arc-style browser
on ungoogled-chromium. This repository builds the
[alerse](https://github.com/VizzleTF/alerse) patch series on top of
[ungoogled-chromium-portablelinux](https://github.com/ungoogled-software/ungoogled-chromium-portablelinux);
both are git submodules.

![Alerse: the Personal Space with pinned items, a Reading folder and favorites](https://raw.githubusercontent.com/VizzleTF/alerse/main/docs/images/sidebar.png)

Features: see [Features](https://github.com/VizzleTF/alerse#features) and
[Differences from Arc](https://github.com/VizzleTF/alerse#differences-from-arc). On Linux
Alerse looks as on Windows: Arc for macOS everywhere but the top bar.

## Download

Open the [latest release](https://github.com/VizzleTF/alerse-linux/releases/latest) and
download, under **Assets**, the file for your machine (`x86_64` for Intel and AMD, `arm64`
for Arm):

| File | Run |
|---|---|
| `Alerse-<version>-<arch>.AppImage` | `chmod +x Alerse-*.AppImage && ./Alerse-*.AppImage` |
| `Alerse-<version>-<arch>_linux.tar.xz` | Unpack, then `./chrome-wrapper` in the unpacked directory |
| `Alerse-<version>-<arch>.AppImage.zsync` | Delta updates of the AppImage with [AppImageUpdate](https://github.com/AppImageCommunity/AppImageUpdate) |
| `SHA256SUMS` | SHA-256 of every file in the release: `sha256sum -c --ignore-missing SHA256SUMS` |

A release appears as soon as its first architecture is built, usually x86_64, and the
other one's files are added to it when they are ready, some hours apart; `SHA256SUMS` is
rewritten each time.

To sync with your other devices, open `chrome://alerse-sync`.

The only release so far, 0.1.1, is on Chromium 156, released under the project's
earlier name, and keeps the profile in `~/.config/chromium`. From the first release on
Chromium 157 the profile is in `~/.config/alerse`; its first start moves an earlier
release's profile there, or keeps using it where it is while that release still runs.
Delete the old AppImage or folder afterwards; it updates to Alerse's with
AppImageUpdate, as each release also carries a `.zsync` under the old file name.

Alerse does not update itself. AppImage users can update with the `.zsync` file and
AppImageUpdate; otherwise check the releases page. From the first release on Chromium 157
the menu of the sidebar's logo shows "Update to Alerse X.Y.Z" when a newer release is
out; 0.1.1 has no such notice.

### If Alerse does not start: the sandbox

Chromium's sandbox needs unprivileged user namespaces. Ubuntu 23.10 and later allow them
only to programs an AppArmor profile lets in, so Alerse exits with "No usable sandbox!"
until it has one. Add it once (Ubuntu's own `/etc/apparmor.d/chrome` is the same):

```sh
sudo tee /etc/apparmor.d/alerse > /dev/null <<'EOF'
abi <abi/4.0>,
include <tunables/global>

profile alerse /{opt/alerse,tmp/.mount_*/opt/alerse}/chrome flags=(unconfined) {
  userns,
  include if exists <local/alerse>
}
EOF
sudo apparmor_parser -r /etc/apparmor.d/alerse
```

It covers the AppImage, which runs from `/tmp/.mount_*`, and the tar.xz unpacked to
`/opt/alerse`:

```sh
sudo mkdir -p /opt/alerse
sudo tar -xJf Alerse-*_linux.tar.xz -C /opt/alerse --strip-components=1
/opt/alerse/chrome-wrapper
```

On a system without user namespaces at all, the tar.xz can use the setuid sandbox
helper it ships instead: run `sudo chown root:root chrome-sandbox && sudo chmod 4755
chrome-sandbox` in its directory. Do not run Alerse with `--no-sandbox`.

## How releases are built

Pushing a tag runs [release.yml](.github/workflows/release.yml) on GitHub-hosted
runners. A full Chromium build takes longer than the 6 hours a job may run, so
[build.yml](.github/workflows/build.yml) chains up to 10 jobs per architecture: each
builds until it times out and passes the build tree to the next one, and the jobs after
the one that finishes do not start. The package job then packages, and
[publish.yml](.github/workflows/publish.yml) adds the packages to the release right away,
one architecture at a time. If one architecture fails, the other is still published;
re-run the failed jobs to add it. Running the workflow by hand builds without publishing.

x86_64 releases are built with profile-guided optimization (PGO), as Chrome is, with the
profile the Chromium release tarball ships (`chrome/build/linux.pgo.txt` names it); the
build stops before compiling if it is missing. There is no Linux arm64 profile, so arm64
is built without PGO.

### Versions and tags

A release is tagged `v` + `alerse/VERSION`, the version of the core the submodule is
on: the build compiles that version into the browser and into its Chromium version number
(see [versioning](https://github.com/VizzleTF/alerse/blob/main/docs/versioning.md)), so a
release of this repository alone raises the core's `VERSION` too. That number must also be
above the latest release's: on the same Chromium the patch number keeps counting (0.1.7 is
followed by 0.2.8, not 0.2.0). The release workflow checks both first and fails before
building.

[dependabot](.github/dependabot.yml) proposes updates of the actions and submodules, and
[upstream.yml](.github/workflows/upstream.yml) opens an issue every time
ungoogled-chromium-portablelinux releases a newer Chromium.

## Build from source

Requirements: Linux with Docker, git, about 120 GB of free disk space and 16 GB of RAM.
The build runs in upstream's Debian container, so no other packages are needed.

```sh
git clone --recurse-submodules https://github.com/VizzleTF/alerse-linux.git
cd alerse-linux
./assemble.sh
ungoogled-chromium-portablelinux/scripts/docker-build.sh
ungoogled-chromium-portablelinux/package/docker-package.sh
```

The browser is `ungoogled-chromium-portablelinux/build/src/out/Default/chrome`, the
packages are in `ungoogled-chromium-portablelinux/build/release/`.

`assemble.sh` adds the Alerse patches, `alerse/flags.gn`, the branding step, PGO for
x86_64 and Alerse's packaging to the ungoogled-chromium-portablelinux submodule, and
builds the `chrome_sandbox` helper instead of chromedriver, which no package ships. It
also copies the core's `VERSION` into the build, which stamps the release into the
Chromium version number. Running it again starts from
the submodule as committed; `./assemble.sh --reset` restores the submodule. Neither
touches the build tree in `build/`.

### Rebuild after changing a patch

`docker-build.sh` deletes `out/` before it builds. To rebuild only what changed, run
ninja in the container:

```sh
cd ungoogled-chromium-portablelinux
docker run --rm -it -u "$(id -u):$(id -g)" -v "$PWD:/repo" chromium-builder:trixie-slim \
    bash -c 'cd /repo/build/src && ninja -C out/Default chrome chrome_sandbox'
```

## Check the patches

```sh
./check-patches.sh
```

Applies the whole series to the Chromium release source in a few minutes:
ungoogled-chromium's patches, then this repository's, then Alerse's, which must
apply with no fuzz. It downloads the release tarball once into `build-check/cache`
and unpacks only the files the patches touch. CI runs it on every push.

## Change the patches

Patches live in the `alerse` submodule; see
[Writing and refreshing patches](https://github.com/VizzleTF/alerse/blob/main/docs/patching.md).

## License

BSD-3-Clause.
