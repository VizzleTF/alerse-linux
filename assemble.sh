#!/bin/bash
# Prepares ungoogled-chromium-portablelinux to build Arcomium: adds the patches of
# the arcomium submodule to its patch series, arcomium/flags.gn to its GN flags,
# a step that copies arcomium/branding over the source tree and renames the
# product after patching, PGO for x86_64, the chrome_sandbox target in place of
# chromedriver, and Arcomium's packaging. Its build scripts then build
# Arcomium. Running it again starts from the submodule as committed;
# `assemble.sh --reset` only restores the submodule. The build tree is kept.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UP="$ROOT/ungoogled-chromium-portablelinux"
CORE="$ROOT/arcomium"

# Restore the submodule; build/ is ignored there, so the build tree stays.
git -C "$UP" checkout -q -- .
git -C "$UP" clean -fdq
[ "${1:-}" = "--reset" ] && exit 0

# The patches, after upstream's.
cp -r "$CORE/patches" "$UP/patches/arcomium"
grep -v -e '^#' -e '^[[:space:]]*$' "$CORE/patches/series" | sed 's|^|arcomium/|' \
    >> "$UP/patches/series"

# The GN flags, after the Linux ones.
{ echo; cat "$CORE/flags.gn"; } >> "$UP/flags.linux.gn"

# Arcomium's own source files and binary branding files are copied over the
# tree, not patched in, and renaming the product in the strings moves hundreds
# of translations, which a script does better; the script also numbers the
# release in chrome/VERSION from arcomium/VERSION. They run in the build
# container, where the submodule is /repo.
mkdir -p "$UP/arcomium"
cp -r "$CORE/src" "$CORE/branding" "$CORE/tools" "$CORE/VERSION" "$UP/arcomium/"
python3 - "$UP/scripts/shared.sh" "$UP/.github/scripts/build.sh" <<'EOF'
import sys
from pathlib import Path
p = Path(sys.argv[1])
t = p.read_text()
anchor = '        touch "${_src_dir}/.patched.stamp"\n'
step = ('        cp -r "${_root}/arcomium/src/." "${_src_dir}/"\n'
        '        cp -r "${_root}/arcomium/branding/." "${_src_dir}/"\n'
        '        python3 "${_root}/arcomium/tools/rename_product.py" "${_src_dir}"\n')
assert t.count(anchor) == 1, 'apply_patches() changed upstream'
t = t.replace(anchor, step + anchor)

# PGO on x86_64, as Chrome's builds have it: upstream's flags.gn turns it off,
# but the release tarball ships Chromium's Linux profile. Builds for x86_64
# fail here without it rather than build slower. arm64 has no Linux profile.
anchor = '    echo "v8_target_cpu = \\"$_build_arch\\"" | tee -a "${_out_dir}/args.gn"\n'
step = ('    if [ "$_build_arch" = x64 ]; then\n'
        '        _pgo_profile="${_src_dir}/chrome/build/pgo_profiles/$(tr -d \'[:space:]\' < "${_src_dir}/chrome/build/linux.pgo.txt")"\n'
        '        if [ ! -s "$_pgo_profile" ]; then\n'
        '            echo "Arcomium: the PGO profile $_pgo_profile is missing" >&2\n'
        '            exit 1\n'
        '        fi\n'
        '        printf \'%s\\n\' chrome_pgo_phase=2 v8_enable_builtins_optimization=true | tee -a "${_out_dir}/args.gn"\n'
        '    fi\n')
assert t.count(anchor) == 1, 'write_gn_args() changed upstream'
t = t.replace(anchor, anchor + step)

# Build the setuid sandbox helper for the tar.xz instead of chromedriver,
# which the packages do not ship.
targets = 'ninja -C out/Default chrome chromedriver'
assert t.count(targets) == 1, 'maybe_build() changed upstream'
p.write_text(t.replace(targets, 'ninja -C out/Default chrome chrome_sandbox'))

p = Path(sys.argv[2])
t = p.read_text()
for old, new in ((targets, 'ninja -C out/Default chrome chrome_sandbox'),
                 ('[ -x "${_out_dir}/chromedriver" ]', '[ -x "${_out_dir}/chrome_sandbox" ]')):
    assert t.count(old) == 1, f'{p} changed upstream'
    t = t.replace(old, new)
p.write_text(t)
EOF

# Arcomium's packages instead of ungoogled-chromium's.
cp "$ROOT/package/package.sh" "$UP/scripts/package.sh"
cp "$ROOT/package/arcomium.desktop" "$UP/package/arcomium.desktop"
# Its packages are named after the release tag, when there is one.
sed -i 's|-e APPIMAGE_EXTRACT_AND_RUN=1|& -e ARCOMIUM_VERSION|' "$UP/package/docker-package.sh"
grep -q ARCOMIUM_VERSION "$UP/package/docker-package.sh"

echo "assembled: $(grep -c '^arcomium/' "$UP/patches/series") Arcomium patches"
