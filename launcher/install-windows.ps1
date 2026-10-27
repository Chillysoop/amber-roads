# Installs the self-updating Amber Roads launcher with Start menu and desktop shortcuts.
# Run in PowerShell:
#   irm https://raw.githubusercontent.com/Chillysoop/amber-roads/main/launcher/install-windows.ps1 | iex
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$repo = if ($env:AMBER_ROADS_REPO) { $env:AMBER_ROADS_REPO } else { 'Chillysoop/amber-roads' }
$dataDir = Join-Path $env:LOCALAPPDATA 'AmberRoads'
$launcher = Join-Path $dataDir 'amber-roads.ps1'
New-Item -ItemType Directory -Force -Path $dataDir | Out-Null
# Fetched by PowerShell rather than a browser, so there is no SmartScreen mark on it.
Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/$repo/main/launcher/amber-roads.ps1" -OutFile $launcher

$shell = New-Object -ComObject WScript.Shell
$targets = @(
  (Join-Path ([Environment]::GetFolderPath('Programs')) 'Amber Roads.lnk'),
  (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Amber Roads.lnk')
)
foreach ($path in $targets) {
  $shortcut = $shell.CreateShortcut($path)
  $shortcut.TargetPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
  $shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$launcher`""
  $shortcut.WorkingDirectory = $dataDir
  $shortcut.Save()
}
Write-Host "Installed. Launch Amber Roads from the Start menu or desktop; it updates to the latest main build on every launch."
