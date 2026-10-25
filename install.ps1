# Install chroma-crab on Windows. From a PowerShell window in this folder:
#
#   powershell -ExecutionPolicy Bypass -File install.ps1          install
#   powershell -ExecutionPolicy Bypass -File install.ps1 -Alias   also make plain `claude` pick a colour
#
# Scripts go to %LOCALAPPDATA%\chroma-crab, with chroma-crab.cmd in its bin
# folder on your user PATH. Themes go to %USERPROFILE%\.claude\themes
# (or $env:CLAUDE_CONFIG_DIR\themes).

param([switch]$Alias)
$ErrorActionPreference = 'Stop'

$src = $PSScriptRoot
$dest = Join-Path $env:LOCALAPPDATA 'chroma-crab'
$binDir = Join-Path $dest 'bin'
$config = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME '.claude' }
$themeDir = Join-Path $config 'themes'

New-Item -ItemType Directory -Force -Path $binDir, $themeDir | Out-Null
Copy-Item (Join-Path $src 'windows\chroma-crab.ps1'), (Join-Path $src 'windows\chroma-crab-statusline.ps1') $dest -Force
Copy-Item (Join-Path $src 'windows\chroma-crab.cmd') $binDir -Force
$themes = Get-ChildItem (Join-Path $src 'themes') -Filter 'crab-*.json'
$themes | Copy-Item -Destination $themeDir -Force
Write-Host "Installed chroma-crab to $dest"
Write-Host "Installed $($themes.Count) crab themes to $themeDir"

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if (-not (($userPath -split ';') -contains $binDir)) {
  $newPath = if ($userPath) { "$userPath;$binDir" } else { $binDir }
  [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
  Write-Host "Added $binDir to your user PATH. Open a new terminal to pick it up."
}

if ($Alias) {
  $line = 'function claude { chroma-crab @args }  # chroma-crab: a crab colour per window'
  $current = if (Test-Path -LiteralPath $PROFILE) { Get-Content -LiteralPath $PROFILE -Raw } else { '' }
  if ($current -match 'chroma-crab') {
    Write-Host "$PROFILE already mentions chroma-crab, leaving it alone."
  } else {
    New-Item -ItemType Directory -Force -Path (Split-Path $PROFILE) | Out-Null
    Add-Content -LiteralPath $PROFILE -Value "`r`n$line"
    Write-Host "Added a claude function to $PROFILE."
    # This installer runs under -ExecutionPolicy Bypass, so skip the Process
    # scope to see what a normal PowerShell window will use.
    $policy = Get-ExecutionPolicy -List |
      Where-Object { $_.Scope -ne 'Process' -and $_.ExecutionPolicy -ne 'Undefined' } |
      Select-Object -First 1
    if (-not $policy -or $policy.ExecutionPolicy -eq 'Restricted') {
      Write-Host "PowerShell won't load your profile until scripts are allowed. To allow your own:"
      Write-Host "  Set-ExecutionPolicy -Scope CurrentUser RemoteSigned"
    }
  }
}
