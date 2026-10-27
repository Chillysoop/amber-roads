# Amber Roads launcher for Windows.
# Each launch it asks the rolling "main-latest" release which commit it was
# built from. If that differs from the installed copy, it downloads the zip,
# checks its SHA-256, swaps it in, then starts the game. With no network (or
# any update error) it starts the copy already installed.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$repo = if ($env:AMBER_ROADS_REPO) { $env:AMBER_ROADS_REPO } else { 'Chillysoop/amber-roads' }
$baseUrl = if ($env:AMBER_ROADS_BASE_URL) { $env:AMBER_ROADS_BASE_URL } else { "https://github.com/$repo/releases/download/main-latest" }
$platform = 'x86_64-win32'
$dataDir = Join-Path $env:LOCALAPPDATA 'AmberRoads'
$currentDir = Join-Path $dataDir 'current'
$logFile = Join-Path $dataDir 'launcher.log'
New-Item -ItemType Directory -Force -Path $dataDir | Out-Null

function Log($message) { Add-Content -Path $logFile -Value "$((Get-Date).ToUniversalTime().ToString('s'))Z $message" }
function Read-Build($path) {
  $fields = @{}
  foreach ($line in Get-Content $path) {
    $i = $line.IndexOf('=')
    if ($i -gt 0) { $fields[$line.Substring(0, $i)] = $line.Substring($i + 1) }
  }
  $fields
}

$installed = $null
$installedBuild = Join-Path $currentDir 'build.txt'
if (Test-Path $installedBuild) { $installed = (Read-Build $installedBuild)['commit'] }

$work = Join-Path $dataDir ("update-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
try {
  Invoke-WebRequest -UseBasicParsing -TimeoutSec 15 -Uri "$baseUrl/build.txt" -OutFile "$work\build.txt"
  $build = Read-Build "$work\build.txt"
  $latest = $build['commit']
  $expected = $build["sha256.$platform"]
  if (-not $latest -or -not $expected) { throw "build.txt has no $platform build" }
  if ($latest -eq $installed) {
    Log "up to date at $latest"
  } else {
    Log "updating $installed -> $latest"
    Invoke-WebRequest -UseBasicParsing -TimeoutSec 300 -Uri "$baseUrl/amber-roads-$platform.zip" -OutFile "$work\game.zip"
    # A mismatch usually means CI is mid-upload; the next launch picks it up.
    if ((Get-FileHash -Algorithm SHA256 "$work\game.zip").Hash.ToLower() -ne $expected) { throw 'checksum mismatch' }
    Expand-Archive -Path "$work\game.zip" -DestinationPath "$work\new"
    Copy-Item "$work\build.txt" "$work\new\build.txt"
    if (Test-Path $currentDir) { Remove-Item -Recurse -Force $currentDir }
    Move-Item "$work\new" $currentDir
    Log "installed $latest"
  }
} catch {
  Log "update skipped: $($_.Exception.Message)"
} finally {
  Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}

$exe = Get-ChildItem -Path $currentDir -Filter '*.exe' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if ($exe) {
  Log "starting $($exe.FullName)"
  if ($args.Count -gt 0) {
    Start-Process -FilePath $exe.FullName -WorkingDirectory $exe.DirectoryName -ArgumentList $args
  } else {
    Start-Process -FilePath $exe.FullName -WorkingDirectory $exe.DirectoryName
  }
} else {
  Log 'ERROR no game installed and the download failed'
  Add-Type -AssemblyName PresentationFramework
  [System.Windows.MessageBox]::Show("No game is installed yet and the download failed. Check your connection and try again.`n`nLog: $logFile", 'Amber Roads') | Out-Null
  exit 1
}
