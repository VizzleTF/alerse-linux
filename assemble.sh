#!/bin/bash
# Prepares ungoogled-chromium-portablelinux to build Arcomium: adds the patches of
# the arcomium submodule to its patch series, arcomium/flags.gn to its GN flags,
# a step that copies arcomium/branding over the source tree and renames the
# product after patching, and Arcomium's packaging. Its build scripts then build
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
# of translations, which a script does better. They run in the build
# container, where the submodule is /repo.
mkdir -p "$UP/arcomium"
cp -r "$CORE/src" "$CORE/branding" "$CORE/tools" "$UP/arcomium/"
python3 - "$UP/scripts/shared.sh" <<'EOF'
import sys
from pathlib import Path
p = Path(sys.argv[1])
t = p.read_text()
anchor = '        touch "${_src_dir}/.patched.stamp"\n'
step = ('        cp -r "${_root}/arcomium/src/." "${_src_dir}/"\n'
        '        cp -r "${_root}/arcomium/branding/." "${_src_dir}/"\n'
        '        python3 "${_root}/arcomium/tools/rename_product.py" "${_src_dir}"\n')
assert t.count(anchor) == 1, 'apply_patches() changed upstream'
p.write_text(t.replace(anchor, step + anchor))
EOF

# Arcomium's packages instead of ungoogled-chromium's.
cp "$ROOT/package/package.sh" "$UP/scripts/package.sh"
cp "$ROOT/package/arcomium.desktop" "$UP/package/arcomium.desktop"
# Its packages are named after the release tag, when there is one.
sed -i 's|-e APPIMAGE_EXTRACT_AND_RUN=1|& -e ARCOMIUM_VERSION|' "$UP/package/docker-package.sh"
grep -q ARCOMIUM_VERSION "$UP/package/docker-package.sh"

echo "assembled: $(grep -c '^arcomium/' "$UP/patches/series") Arcomium patches"
