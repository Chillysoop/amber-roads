#!/bin/sh
# Installs the self-updating Amber Roads launcher.
#   macOS: ~/Applications/Amber Roads.app (Launchpad, Spotlight, Dock) plus a Desktop shortcut
#   Linux: ~/.local/bin/amber-roads plus menu and Desktop entries
# Run with:
#   curl -fsSL https://raw.githubusercontent.com/Chillysoop/amber-roads/main/launcher/install.sh | sh
set -eu

repo=${AMBER_ROADS_REPO:-Chillysoop/amber-roads}
launcher_url=${AMBER_ROADS_LAUNCHER_URL:-https://raw.githubusercontent.com/$repo/main/launcher/amber-roads.sh}

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
curl -fsSL "$launcher_url" -o "$tmp"

case "$(uname -s)" in
  Darwin)
    # Built locally (not downloaded through a browser), so Gatekeeper never quarantines it.
    app="$HOME/Applications/Amber Roads.app"
    rm -rf "$app"
    mkdir -p "$app/Contents/MacOS"
    cp "$tmp" "$app/Contents/MacOS/amber-roads"
    chmod +x "$app/Contents/MacOS/amber-roads"
    cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Amber Roads</string>
  <key>CFBundleDisplayName</key><string>Amber Roads</string>
  <key>CFBundleIdentifier</key><string>com.chillysoop.amberroads.launcher</string>
  <key>CFBundleExecutable</key><string>amber-roads</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST
    # Desktop shortcut: a symlink Finder opens like the app itself.
    desktop_dir="$HOME/Desktop"
    if [ -d "$desktop_dir" ]; then
      rm -rf "$desktop_dir/Amber Roads.app"
      ln -s "$app" "$desktop_dir/Amber Roads.app"
    fi
    printf 'Installed %s with a shortcut on your Desktop.\nDouble-click it; it updates to the latest main build on every launch.\n' "$app"
    ;;
  Linux)
    bin_dir="$HOME/.local/bin"
    apps_dir="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
    mkdir -p "$bin_dir" "$apps_dir"
    cp "$tmp" "$bin_dir/amber-roads"
    chmod +x "$bin_dir/amber-roads"
    cat > "$apps_dir/amber-roads.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Amber Roads
Exec=$bin_dir/amber-roads
Terminal=false
Categories=Game;
DESKTOP
    desktop_dir=$(xdg-user-dir DESKTOP 2>/dev/null || printf '%s' "$HOME/Desktop")
    if [ -d "$desktop_dir" ]; then
      cp "$apps_dir/amber-roads.desktop" "$desktop_dir/amber-roads.desktop"
      chmod +x "$desktop_dir/amber-roads.desktop"
    fi
    printf 'Installed %s with menu and Desktop entries.\nRun amber-roads; it updates to the latest main build on every launch.\n' "$bin_dir/amber-roads"
    ;;
  *)
    echo 'On Windows, use launcher/install-windows.ps1 instead.' >&2
    exit 1 ;;
esac
