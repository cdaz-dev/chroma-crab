# Launch Claude Code with a crab colour that no other open window is using,
# so you can tell terminal windows apart at a glance. Windows version of
# bin/claude-crab. Works in Windows PowerShell 5.1 and PowerShell 7.
#
# Run it through claude-crab.cmd, which install.ps1 puts on your PATH.

$ErrorActionPreference = 'Stop'

$config = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME '.claude' }
$state = Join-Path $PSScriptRoot 'state'
New-Item -ItemType Directory -Force -Path $state | Out-Null

# Handed out in this order. Override with e.g. $env:CLAUDE_CRAB_COLOURS = 'crab-teal crab-pink'
$colours = if ($env:CLAUDE_CRAB_COLOURS) { $env:CLAUDE_CRAB_COLOURS -split '\s+' | Where-Object { $_ } } else {
  @('crab-coral', 'crab-orange', 'crab-yellow', 'crab-green', 'crab-teal',
    'crab-cyan', 'crab-blue', 'crab-purple', 'crab-pink', 'crab-silver')
}

# A claim file holds the owner's PID and start time. Checking both guards
# against Windows handing the same PID to an unrelated process later.
function Test-HolderAlive($file) {
  try {
    $id, $ticks = (Get-Content -LiteralPath $file -ErrorAction Stop) -split '\s+'
    $p = Get-Process -Id ([int]$id) -ErrorAction Stop
    return $p.StartTime.Ticks -eq [long]$ticks
  } catch {
    return $false
  }
}

Get-ChildItem -LiteralPath $state -Filter '*.pid' | ForEach-Object {
  if (-not (Test-HolderAlive $_.FullName)) { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
}

# Claim the first free colour. CreateNew fails if the file exists, so two
# windows opened in the same instant cannot grab the same one.
$me = Get-Process -Id $PID
$slug = $null
$claim = $null
foreach ($c in $colours) {
  $path = Join-Path $state "$c.pid"
  try {
    $fs = [System.IO.File]::Open($path, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write)
    $bytes = [System.Text.Encoding]::ASCII.GetBytes("$PID $($me.StartTime.Ticks)")
    $fs.Write($bytes, 0, $bytes.Length)
    $fs.Close()
    $slug = $c
    $claim = $path
    break
  } catch {
    continue
  }
}

# All taken: borrow one at random without claiming it.
if (-not $slug) { $slug = $colours | Get-Random }

# The status line reads this to tint its context gauge to match the crab.
$env:CLAUDE_CRAB_COLOUR = $slug

# Settings go in through a file. Passing a JSON string to a native exe from
# Windows PowerShell 5.1 mangles the quotes. --settings merges over
# settings.json key by key, so nothing else in your config changes.
$settings = @{ theme = "custom:$slug" }
$statusScript = Join-Path $PSScriptRoot 'claude-statusline.ps1'
if ($env:CLAUDE_CRAB_STATUSLINE -ne '0' -and (Test-Path -LiteralPath $statusScript)) {
  # Same PowerShell that is running this script. Forward slashes so the command
  # survives whichever shell Claude Code hands it to (cmd or Git Bash).
  $shell = $me.Path -replace '\\', '/'
  $script = $statusScript -replace '\\', '/'
  $settings.statusLine = @{
    type    = 'command'
    command = "`"$shell`" -NoProfile -ExecutionPolicy Bypass -File `"$script`""
    padding = 0
  }
}
$settingsFile = Join-Path $state "$slug.settings.json"
[System.IO.File]::WriteAllText($settingsFile, ($settings | ConvertTo-Json -Depth 4))

if (-not (Test-Path -LiteralPath (Join-Path $config "themes\$slug.json"))) {
  [Console]::Error.WriteLine("claude-crab: no theme file at $config\themes\$slug.json (did you run install.ps1?)")
}

# Only real executables, so a `claude` function in your $PROFILE that calls
# claude-crab cannot end up calling itself.
$bin = Get-Command claude -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
$bin = if ($bin) { $bin.Source } else { Join-Path $HOME '.local\bin\claude.exe' }

$code = 0
try {
  & $bin --settings $settingsFile @args
  $code = $LASTEXITCODE
} finally {
  if ($claim) { Remove-Item -LiteralPath $claim -Force -ErrorAction SilentlyContinue }
}
exit $code
