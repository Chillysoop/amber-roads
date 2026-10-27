# Self-updating desktop build

Every push to `main` bundles the game for macOS (Apple Silicon and Intel), Windows and Linux and publishes it to the rolling [`main-latest` release](https://github.com/Chillysoop/amber-roads/releases/tag/main-latest) (`.github/workflows/desktop-build.yml`). The launcher installed below checks that release each time you open the game. If `main` has moved on, it downloads the new build (about 3 MB), verifies its SHA-256 and swaps it in before starting. Offline, it starts the build you already have.

## Install once

**macOS** (Terminal):

```sh
curl -fsSL https://raw.githubusercontent.com/Chillysoop/amber-roads/main/launcher/install.sh | sh
```

This creates `~/Applications/Amber Roads.app`. Open it from Launchpad or Spotlight, or drag it to the Dock.

**Windows** (PowerShell):

```powershell
irm https://raw.githubusercontent.com/Chillysoop/amber-roads/main/launcher/install-windows.ps1 | iex
```

This adds Amber Roads to the Start menu and desktop.

**Linux**: the same `install.sh` command as macOS. It adds `~/.local/bin/amber-roads` and a menu entry.

## About unsigned builds

The game isn't signed with an Apple Developer ID or a Windows certificate. The installers avoid the usual warnings because they fetch files with `curl` / PowerShell rather than a browser, so nothing gets the "downloaded from the internet" mark that triggers Gatekeeper or SmartScreen. On macOS the launcher also ad-hoc signs each build, which Apple Silicon needs to run it.

If you download a zip from the release page by hand instead, macOS will refuse to open it. Right-click the app and choose Open, or run `xattr -cr "Amber Roads.app"`.

## Where things live

| | Installed game | Log |
|---|---|---|
| macOS | `~/Library/Application Support/Amber Roads/current` | `launcher.log` beside it |
| Windows | `%LOCALAPPDATA%\AmberRoads\current` | `launcher.log` beside it |
| Linux | `~/.local/share/amber-roads/current` | `launcher.log` beside it |

`current/build.txt` names the commit you're running. Delete `current` to force a fresh download.

To build the release files locally: `./scripts/package-desktop.sh` (writes `dist/release/`).
