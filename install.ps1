# Install chroma-crab on Windows. From a PowerShell window in this folder:
#
#   powershell -ExecutionPolicy Bypass -File install.ps1             install, and make `claude` itself pick a colour
#   powershell -ExecutionPolicy Bypass -File install.ps1 -NoShim     install the chroma-crab command only
#   powershell -ExecutionPolicy Bypass -File install.ps1 -Uninstall  remove everything this script added
#
# Everything goes in %LOCALAPPDATA%\chroma-crab. Themes go to
# %USERPROFILE%\.claude\themes (or $env:CLAUDE_CONFIG_DIR\themes).

param([switch]$NoShim, [switch]$Uninstall)
$ErrorActionPreference = 'Stop'

$src = $PSScriptRoot
$dest = Join-Path $env:LOCALAPPDATA 'chroma-crab'
$binDir = Join-Path $dest 'bin'
$shimDir = Join-Path $dest 'shim'
$config = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME '.claude' }
$themeDir = Join-Path $config 'themes'

function Get-UserPath { @(([Environment]::GetEnvironmentVariable('Path', 'User') -split ';') | Where-Object { $_ }) }
function Set-UserPath($parts) { [Environment]::SetEnvironmentVariable('Path', ($parts -join ';'), 'User') }

if ($Uninstall) {
  Set-UserPath (Get-UserPath | Where-Object { $_ -ne $binDir -and $_ -ne $shimDir })
  Remove-Item -Recurse -Force $dest -ErrorAction SilentlyContinue
  Get-ChildItem $themeDir -Filter 'crab-*.json' -ErrorAction SilentlyContinue | Remove-Item -Force
  Write-Host 'Removed chroma-crab. Open a new terminal to drop it from PATH.'
  exit 0
}

New-Item -ItemType Directory -Force -Path $binDir, $themeDir | Out-Null
Copy-Item (Join-Path $src 'windows\chroma-crab.ps1'), (Join-Path $src 'windows\chroma-crab-statusline.ps1') $dest -Force
Copy-Item (Join-Path $src 'windows\chroma-crab.cmd') $binDir -Force
$themes = Get-ChildItem (Join-Path $src 'themes') -Filter 'crab-*.json'
$themes | Copy-Item -Destination $themeDir -Force
Write-Host "Installed chroma-crab to $dest"
Write-Host "Installed $($themes.Count) crab themes to $themeDir"

$path = Get-UserPath | Where-Object { $_ -ne $binDir -and $_ -ne $shimDir }
$path = @($path) + $binDir

if (-not $NoShim) {
  # A stand-in claude.exe, placed ahead of the real one on PATH. Anything that
  # runs claude by name (a terminal, a keybind, a Windows Terminal profile, a
  # launcher) goes through chroma-crab without any change on your side.
  # Compiled with the C# compiler that ships with Windows, via Windows
  # PowerShell 5.1 (PowerShell 7's Add-Type can't build an .exe).
  New-Item -ItemType Directory -Force -Path $shimDir | Out-Null
  $exe = Join-Path $shimDir 'claude.exe'
  $cs = Join-Path $src 'windows\claude-shim.cs'
  Remove-Item -LiteralPath $exe -Force -ErrorAction SilentlyContinue
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Add-Type -TypeDefinition (Get-Content -Raw -LiteralPath '$cs') -OutputAssembly '$exe' -OutputType ConsoleApplication"
  if (-not (Test-Path -LiteralPath $exe)) { throw "Couldn't build $exe" }
  $path = @($shimDir) + $path
  Write-Host "Put a claude.exe stand-in first on your user PATH ($shimDir)"
}

Set-UserPath $path
Write-Host ''
Write-Host 'Open a new terminal to use it. Keybinds and shortcuts pick it up after you sign out and back in.'
