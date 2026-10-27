#!/bin/sh
# Project-local Defold toolchain: nothing is installed globally.
# Pins and checksums match Relay Company's verified setup (Bob 1.13.2, Temurin 25):
# https://github.com/defold/defold/releases/tag/1.13.2
# https://github.com/adoptium/temurin25-binaries/releases/tag/jdk-25.0.4.1%2B1
set -eu

repo_dir=$(CDPATH= cd -P "$(dirname "$0")/.." && pwd)
project_dir="$repo_dir/game"
tools_dir="$repo_dir/.local-tools/defold"
bob_version=1.13.2
bob_sha=79f60022a80c52bbb88a1ec7ad44d7771a70cec658e3950c8f0134554078e9d0
jdk_version=25.0.4.1+1

fail() { printf '\nAmber Roads: %s\n' "$*" >&2; exit 1; }
usage() {
  cat <<'USAGE'
Usage: ./scripts/defold.sh [command]
  test [suite ...]   Run the headless Lua tests (all, or only named suites)
  build [platform]   Compile game data for this host or a target platform
  bundle [platform]  Build a standalone game in dist/<platform>/
  run                Bundle for this computer and launch it
  version            Install/verify the local tools and print their versions

Platforms: arm64-macos, x86_64-macos, x86_64-linux, arm64-linux, x86_64-win32
First use downloads about 400 MB of verified tools into .local-tools/.
USAGE
}

command_name=${1:-run}
if [ "$#" -gt 0 ]; then shift; fi
case "$command_name" in
  help|-h|--help) usage; exit 0 ;;
  version|build|bundle|run|test) ;;
  *) usage; fail "Unknown command: $command_name" ;;
esac

case "$(uname -s)/$(uname -m)" in
  Darwin/arm64)
    host_platform=arm64-macos; jdk_asset=OpenJDK25U-jdk_aarch64_mac_hotspot_25.0.4.1_1.tar.gz
    lua_sha=3b9995c542513732a696149822c402bb49f07afe8284a88d49df038af6538f3c
    jdk_sha=61979887f7506a24a57439ff99adb8b3a7fc89977d9cfe3b8984f58a981b7b9d ;;
  Darwin/x86_64)
    host_platform=x86_64-macos; jdk_asset=OpenJDK25U-jdk_x64_mac_hotspot_25.0.4.1_1.tar.gz
    lua_sha=7f28407a300b7a27abf6f2b3d7d5721d86fcf9158cf5602bbd5eafc6de0115c9
    jdk_sha=e6229d9504f7922053ab31821b9e6bee8761daf7b026a3476d1a027563009880 ;;
  Linux/aarch64|Linux/arm64)
    host_platform=arm64-linux; jdk_asset=OpenJDK25U-jdk_aarch64_linux_hotspot_25.0.4.1_1.tar.gz
    lua_sha=d0e15b2820747e45d1ce87e614271390a33309d7aef4d396daa94b8a571b7003
    jdk_sha=69df11a02cfa3ef7d7ca645e03edce6778ec090e100f6ae2b42097865730ac52 ;;
  Linux/x86_64)
    host_platform=x86_64-linux; jdk_asset=OpenJDK25U-jdk_x64_linux_hotspot_25.0.4.1_1.tar.gz
    lua_sha=1dd7894d031f5c3af95273231c9506af7f3650a9a224d19fa83d74b4de15459d
    jdk_sha=dbb698396d478e7fa2b1e50f4103324b2a99b90569ee27c33f2261f9215cf41e ;;
  *) fail 'This script supports macOS and Linux on arm64 or x64. On Windows, open game/game.project in the Defold editor.' ;;
esac

target_platform=$host_platform
if [ "$command_name" = build ] || [ "$command_name" = bundle ]; then
  target_platform=${1:-$host_platform}
fi
case "$target_platform" in
  arm64-macos|x86_64-macos|x86_64-linux|arm64-linux|x86_64-win32) ;;
  *) fail "Unsupported target platform: $target_platform" ;;
esac

if command -v shasum >/dev/null 2>&1; then
  sha256() { shasum -a 256 "$1" | awk '{print $1}'; }
elif command -v sha256sum >/dev/null 2>&1; then
  sha256() { sha256sum "$1" | awk '{print $1}'; }
else
  fail 'Install shasum or sha256sum so downloaded tools can be verified.'
fi

for required_tool in curl unzip tar; do
  command -v "$required_tool" >/dev/null 2>&1 || fail "Install $required_tool and retry."
done

mkdir -p "$tools_dir"
setup_dir=$(mktemp -d "$tools_dir/setup.XXXXXX")
trap 'rm -rf "$setup_dir"' EXIT

download_verified() {
  curl --fail --location --retry 2 --connect-timeout 15 --output "$2" "$1" || fail "Download failed: $1"
  [ "$(sha256 "$2")" = "$3" ] || fail 'Download checksum mismatch; nothing was installed.'
}

bob_jar="$tools_dir/bob-$bob_version.jar"
if [ ! -f "$bob_jar" ]; then
  printf 'Downloading Defold Bob %s...\n' "$bob_version"
  download_verified "https://github.com/defold/defold/releases/download/$bob_version/bob.jar" "$setup_dir/bob.jar" "$bob_sha"
  mv "$setup_dir/bob.jar" "$bob_jar"
fi
[ "$(sha256 "$bob_jar")" = "$bob_sha" ] || fail "Cached Bob failed verification. Delete '$bob_jar' and retry."

# Tests use the exact LuaJIT that ships inside Bob, so they match the engine.
lua_bin="$tools_dir/luajit-$bob_version-$host_platform"
if [ ! -x "$lua_bin" ]; then
  unzip -p "$bob_jar" "libexec/$host_platform/luajit-64" > "$setup_dir/luajit" || fail 'Bob has no LuaJIT for this host.'
  [ "$(sha256 "$setup_dir/luajit")" = "$lua_sha" ] || fail 'Extracted LuaJIT checksum mismatch.'
  chmod +x "$setup_dir/luajit"
  mv "$setup_dir/luajit" "$lua_bin"
fi
if [ "$command_name" = test ]; then
  cd "$project_dir"
  if [ "$#" -gt 0 ]; then AMBER_TEST_SUITES="$*"; export AMBER_TEST_SUITES; fi
  exec "$lua_bin" -e 'package.path="./?.lua;"..package.path; require("tests.run").run()'
fi

jdk_dir="$tools_dir/jdk-$jdk_version-$host_platform"
case "$host_platform" in
  *-macos) java_home="$jdk_dir/Contents/Home" ;;
  *) java_home=$jdk_dir ;;
esac
if [ ! -x "$java_home/bin/java" ]; then
  printf 'Downloading Temurin OpenJDK %s...\n' "$jdk_version"
  download_verified "https://github.com/adoptium/temurin25-binaries/releases/download/jdk-25.0.4.1%2B1/$jdk_asset" "$setup_dir/jdk.tar.gz" "$jdk_sha"
  mkdir "$setup_dir/jdk"
  tar -xzf "$setup_dir/jdk.tar.gz" --strip-components=1 -C "$setup_dir/jdk" || fail 'Could not extract Java.'
  rm -rf "$jdk_dir"
  mv "$setup_dir/jdk" "$jdk_dir"
fi

bob() { "$java_home/bin/java" --enable-native-access=ALL-UNNAMED -jar "$bob_jar" "$@"; }
if [ "$command_name" = version ]; then
  "$java_home/bin/java" -version
  bob --version
  "$lua_bin" -v
  exit 0
fi

cd "$project_dir"
bundle_dir="$repo_dir/dist/$target_platform"
build_game() {
  bob --root "$project_dir" --output "build/$target_platform" --exclude-build-folder build \
    --platform "$target_platform" --architectures "$target_platform" \
    --variant release --archive --bundle-output "$bundle_dir" "$@"
}
if [ "$command_name" = build ]; then
  build_game resolve build
  exit 0
fi
build_game resolve build bundle
printf '\nBundle: %s\n' "$bundle_dir"

if [ "$command_name" = run ]; then
  case "$host_platform" in
    *-macos)
      for executable in "$bundle_dir"/*.app/Contents/MacOS/*; do
        if [ -f "$executable" ] && [ -x "$executable" ]; then exec "$executable"; fi
      done ;;
    *-linux)
      for executable in "$bundle_dir"/*/AmberRoads."${host_platform%%-*}" "$bundle_dir"/*/*.x86_64; do
        if [ -f "$executable" ] && [ -x "$executable" ]; then exec "$executable"; fi
      done ;;
  esac
  fail "No executable found in '$bundle_dir'."
fi
