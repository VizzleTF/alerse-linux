#!/bin/bash
# Checks that the whole patch series applies to the Chromium release source:
# ungoogled-chromium's patches, ungoogled-chromium-portablelinux' and then
# Alerse's, which must apply with no fuzz. It downloads the release tarball
# (hash-checked by ungoogled-chromium's downloads.py) and unpacks only the files
# the patches touch, so it takes minutes, not a build.
#
#   ./check-patches.sh [WORK_DIR]   # default: ./build-check
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UP="$ROOT/ungoogled-chromium-portablelinux"
UC="$UP/ungoogled-chromium"
WORK="${1:-$ROOT/build-check}"

bash "$ROOT/assemble.sh"

series() {
  grep -v -e '^#' -e '^[[:space:]]*$' "$1/series" | sed "s|^|$1/|"
}
mapfile -t PATCHES < <(series "$UC/patches"; series "$UP/patches")

mkdir -p "$WORK/cache"
rm -rf "$WORK/src"
mkdir -p "$WORK/src"
python3 "$UC/utils/downloads.py" retrieve -i "$UC/downloads.ini" -c "$WORK/cache"
version="$(cat "$UC/chromium_version.txt")"
tarball="$(ls "$WORK"/cache/chromium-"$version"*.tar.xz | head -1)"

# The files the patches read; files they create are not in the tarball.
sed -n -e 's|^--- a/\([^[:space:]]*\).*|chromium-'"$version"'/\1|p' "${PATCHES[@]}" |
  sort -u > "$WORK/files.txt"
echo "unpacking $(wc -l < "$WORK/files.txt") files from $(basename "$tarball")"
if ! tar -xJf "$tarball" -C "$WORK/src" --strip-components=1 \
    -T "$WORK/files.txt" 2> "$WORK/tar.err"; then
  # A file one patch creates and a later one changes is not in the tarball.
  if grep -v -e 'Not found in archive' -e 'Exiting with failure' "$WORK/tar.err"; then
    exit 1
  fi
fi

failed=0
for patch in "${PATCHES[@]}"; do
  args=(-p1 --ignore-whitespace --forward --no-backup-if-mismatch -s -i "$patch")
  case "$patch" in
    */patches/arcomium/*) args+=(--fuzz=0) ;;
  esac
  if ! (cd "$WORK/src" && patch "${args[@]}" > "$WORK/patch.out" 2>&1); then
    echo "FAILED: ${patch#"$UP/"}"
    sed 's/^/  /' "$WORK/patch.out"
    failed=1
  fi
done

bash "$ROOT/assemble.sh" --reset
if [ "$failed" -ne 0 ]; then
  echo "Some patches do not apply." >&2
  exit 1
fi
echo "All ${#PATCHES[@]} patches apply."
