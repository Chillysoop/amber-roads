#!/bin/sh
# Amber Roads launcher for macOS and Linux.
# Each launch it asks the rolling "main-latest" release which commit it was
# built from. If that differs from the installed copy, it downloads the zip
# for this computer, checks its SHA-256, swaps it in, then starts the game.
# With no network (or any update error) it starts the copy already installed.
set -u

repo=${AMBER_ROADS_REPO:-Chillysoop/amber-roads}
base_url=${AMBER_ROADS_BASE_URL:-https://github.com/$repo/releases/download/main-latest}

case "$(uname -s)" in
  Darwin) data_dir="$HOME/Library/Application Support/Amber Roads" ;;
  *) data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/amber-roads" ;;
esac
case "$(uname -s)/$(uname -m)" in
  Darwin/arm64) platform=arm64-macos ;;
  Darwin/x86_64) platform=x86_64-macos ;;
  Linux/x86_64) platform=x86_64-linux ;;
  *) platform= ;;
esac

mkdir -p "$data_dir"
log_file="$data_dir/launcher.log"
log() { printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >> "$log_file"; }
notify() {
  if [ "$(uname -s)" = Darwin ]; then
    osascript -e "display notification \"$1\" with title \"Amber Roads\"" >/dev/null 2>&1 || true
  else
    printf 'Amber Roads: %s\n' "$1" >&2
  fi
}
fatal() {
  log "ERROR $1"
  if [ "$(uname -s)" = Darwin ]; then
    osascript -e "display alert \"Amber Roads could not start\" message \"$1\"" >/dev/null 2>&1 || true
  fi
  printf 'Amber Roads: %s\n' "$1" >&2
  exit 1
}

[ -n "$platform" ] || fatal "No desktop build exists for $(uname -s) $(uname -m)."

if command -v shasum >/dev/null 2>&1; then
  sha256() { shasum -a 256 "$1" | awk '{print $1}'; }
else
  sha256() { sha256sum "$1" | awk '{print $1}'; }
fi
field() { sed -n "s/^$1=//p" "$2" | head -n 1; }

current_dir="$data_dir/current"
installed_commit=
[ -f "$current_dir/build.txt" ] && installed_commit=$(field commit "$current_dir/build.txt")

work_dir=$(mktemp -d "$data_dir/update.XXXXXX") || fatal "Could not write to $data_dir."
trap 'rm -rf "$work_dir"' EXIT

update() {
  curl -fsSL --connect-timeout 5 --max-time 15 -o "$work_dir/build.txt" "$base_url/build.txt" || {
    log "offline or no release yet; keeping ${installed_commit:-nothing}"; return 1; }
  latest_commit=$(field commit "$work_dir/build.txt")
  expected_sha=$(field "sha256.$platform" "$work_dir/build.txt")
  [ -n "$latest_commit" ] && [ -n "$expected_sha" ] || { log "build.txt has no $platform build"; return 1; }
  if [ "$latest_commit" = "$installed_commit" ]; then log "up to date at $latest_commit"; return 0; fi

  log "updating ${installed_commit:-nothing} -> $latest_commit"
  notify "Updating to the latest build..."
  curl -fsSL --connect-timeout 5 --max-time 300 -o "$work_dir/game.zip" "$base_url/amber-roads-$platform.zip" || {
    log "download failed"; return 1; }
  # A mismatch usually means CI is mid-upload; the next launch picks it up.
  [ "$(sha256 "$work_dir/game.zip")" = "$expected_sha" ] || { log "checksum mismatch; skipping"; return 1; }

  mkdir "$work_dir/new"
  if [ "$(uname -s)" = Darwin ]; then
    ditto -x -k "$work_dir/game.zip" "$work_dir/new" || { log "unzip failed"; return 1; }
    # CI builds on Linux and can't sign; Apple Silicon needs at least an ad-hoc signature.
    for app in "$work_dir/new"/*.app; do
      xattr -cr "$app" 2>/dev/null || true
      codesign --force --deep --sign - "$app" >/dev/null 2>&1 || log "ad-hoc signing failed for $app"
    done
  else
    unzip -q "$work_dir/game.zip" -d "$work_dir/new" || { log "unzip failed"; return 1; }
  fi
  cp "$work_dir/build.txt" "$work_dir/new/build.txt"

  rm -rf "$data_dir/previous"
  if [ -d "$current_dir" ]; then mv "$current_dir" "$data_dir/previous"; fi
  mv "$work_dir/new" "$current_dir" || fatal "Could not install the update into $current_dir."
  rm -rf "$data_dir/previous"
  log "installed $latest_commit"
}
update || true
# exec skips the EXIT trap, so tidy up now.
rm -rf "$work_dir"

if [ "$(uname -s)" = Darwin ]; then
  for app in "$current_dir"/*.app; do
    if [ -d "$app" ]; then log "starting $app"; exec open -n "$app" --args "$@"; fi
  done
else
  for executable in "$current_dir"/*/AmberRoads.x86_64 "$current_dir"/*/*.x86_64; do
    if [ -f "$executable" ]; then
      chmod +x "$executable"
      log "starting $executable"
      cd "$(dirname "$executable")" && exec "$executable" "$@"
    fi
  done
fi
fatal "No game is installed yet and the download failed. Check your connection and try again (log: $log_file)."
