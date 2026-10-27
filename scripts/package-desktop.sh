#!/bin/sh
# Bundles every desktop platform and zips each one for the rolling
# "main-latest" release that the launchers in launcher/ update from.
# Output: <out_dir>/amber-roads-<platform>.zip plus build.txt, which lists
# the commit and each zip's SHA-256 so launchers can verify downloads.
set -eu

repo_dir=$(CDPATH= cd -P "$(dirname "$0")/.." && pwd)
out_dir=${1:-$repo_dir/dist/release}
platforms=${AMBER_PLATFORMS:-"arm64-macos x86_64-macos x86_64-win32 x86_64-linux"}

if command -v shasum >/dev/null 2>&1; then
  sha256() { shasum -a 256 "$1" | awk '{print $1}'; }
else
  sha256() { sha256sum "$1" | awk '{print $1}'; }
fi
command -v zip >/dev/null 2>&1 || { echo 'Install zip and retry.' >&2; exit 1; }

commit=${GITHUB_SHA:-$(git -C "$repo_dir" rev-parse HEAD)}
version=$(sed -n 's/^version *= *//p' "$repo_dir/game/game.project" | head -n 1)
mkdir -p "$out_dir"
rm -f "$out_dir"/amber-roads-*.zip "$out_dir/build.txt"

{
  printf 'commit=%s\n' "$commit"
  printf 'version=%s\n' "${version:-0}"
  printf 'built_at=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$out_dir/build.txt.tmp"

for platform in $platforms; do
  "$repo_dir/scripts/defold.sh" bundle "$platform"
  bundle_dir="$repo_dir/dist/$platform"
  zip_path="$out_dir/amber-roads-$platform.zip"
  # Zip the app folder ("Amber Roads.app" or "Amber Roads/") without Bob's build report.
  (cd "$bundle_dir" && zip -qry "$zip_path" . -x build_input_data.json)
  printf 'sha256.%s=%s\n' "$platform" "$(sha256 "$zip_path")" >> "$out_dir/build.txt.tmp"
done

mv "$out_dir/build.txt.tmp" "$out_dir/build.txt"
printf '\nRelease files in %s:\n' "$out_dir"
ls -l "$out_dir"
cat "$out_dir/build.txt"
