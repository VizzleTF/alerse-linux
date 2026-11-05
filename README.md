# Arcomium for Linux

Linux builds of [Arcomium](https://github.com/VizzleTF/arcomium), an Arc-style browser
on ungoogled-chromium. This repository builds the
[arcomium](https://github.com/VizzleTF/arcomium) patch series on top of
[ungoogled-chromium-portablelinux](https://github.com/ungoogled-software/ungoogled-chromium-portablelinux);
both are git submodules.

![Arcomium](https://raw.githubusercontent.com/VizzleTF/arcomium/main/docs/images/sidebar.png)

## Download

AppImages and tar.xz archives for x86_64 and arm64 are on the
[Releases](https://github.com/VizzleTF/arcomium-linux/releases) page, with `SHA256SUMS`.

| Package | Run |
|---|---|
| `Arcomium-<version>-x86_64.AppImage` | `chmod +x Arcomium-*.AppImage && ./Arcomium-*.AppImage` |
| `Arcomium-<version>-x86_64_linux.tar.xz` | Unpack, then `./chrome-wrapper` in the unpacked directory |

To sync with your other devices, open `chrome://arcomium-sync`.

## How releases are built

Pushing a tag `v*` runs [release.yml](.github/workflows/release.yml) on GitHub-hosted
runners. A full Chromium build takes longer than the 6 hours a job may run, so
[build.yml](.github/workflows/build.yml) chains up to 10 jobs per architecture: each
builds until it times out and passes the build tree to the next one. The last job
packages, and the release job publishes. Running the workflow by hand builds without
publishing.

## Build from source

Requirements: Linux with Docker, git, about 120 GB of free disk space and 16 GB of RAM.
The build runs in upstream's Debian container, so no other packages are needed.

```sh
git clone --recurse-submodules https://github.com/VizzleTF/arcomium-linux.git
cd arcomium-linux
./assemble.sh
ungoogled-chromium-portablelinux/scripts/docker-build.sh
ungoogled-chromium-portablelinux/package/docker-package.sh
```

The browser is `ungoogled-chromium-portablelinux/build/src/out/Default/chrome`, the
packages are in `ungoogled-chromium-portablelinux/build/release/`.

`assemble.sh` adds the Arcomium patches, `arcomium/flags.gn`, the branding step and
Arcomium's packaging to the ungoogled-chromium-portablelinux submodule. Running it again
starts from the submodule as committed; `./assemble.sh --reset` restores the submodule.
Neither touches the build tree in `build/`.

### Rebuild after changing a patch

`docker-build.sh` deletes `out/` before it builds. To rebuild only what changed, run
ninja in the container:

```sh
cd ungoogled-chromium-portablelinux
docker run --rm -it -u "$(id -u):$(id -g)" -v "$PWD:/repo" chromium-builder:trixie-slim \
    bash -c 'cd /repo/build/src && ninja -C out/Default chrome chromedriver'
```

## Change the patches

Patches live in the `arcomium` submodule; see
[Writing and refreshing patches](https://github.com/VizzleTF/arcomium/blob/main/docs/patching.md).

## License

BSD-3-Clause.
