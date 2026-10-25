# Tests for the Windows scripts. Uses a fake `claude` that records how it was
# called, so no Claude Code install or login is needed. Run it in both
# Windows PowerShell 5.1 and PowerShell 7.
$ErrorActionPreference = 'Stop'

$repo = Split-Path $PSScriptRoot
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("chroma-crab-test-" + [guid]::NewGuid())
$app = Join-Path $tmp 'app'
$fake = Join-Path $tmp 'fake'
$env:CLAUDE_CONFIG_DIR = Join-Path $tmp 'config'
New-Item -ItemType Directory -Force -Path $app, $fake, "$env:CLAUDE_CONFIG_DIR\themes" | Out-Null
Copy-Item "$repo\themes\crab-*.json" "$env:CLAUDE_CONFIG_DIR\themes"

# Same layout install.ps1 creates: scripts in the app folder, the shim in bin.
Copy-Item "$repo\windows\chroma-crab.ps1", "$repo\windows\chroma-crab-statusline.ps1" $app
New-Item -ItemType Directory -Force -Path "$app\bin" | Out-Null
Copy-Item "$repo\windows\chroma-crab.cmd" "$app\bin"
$shim = "$app\bin\chroma-crab.cmd"
$state = "$app\state"

# Fake claude: write its arguments, the settings file it was given and the
# exported colour, then stay open for FAKE_SLEEP seconds like a real session.
Set-Content -LiteralPath "$fake\claude.cmd" -Encoding ASCII -Value @'
@echo off
echo args=%*> "%FAKE_OUT%"
if "%~1"=="--settings" type "%~2" >> "%FAKE_OUT%"
echo colour=%CHROMA_CRAB_COLOUR%>> "%FAKE_OUT%"
echo %* | findstr /c:"--fail" > nul && exit /b 7
if defined FAKE_SLEEP ping -n %FAKE_SLEEP% 127.0.0.1 > nul
exit /b 0
'@
$env:Path = "$fake;$env:Path"

$script:fails = 0
function Check($name, [scriptblock]$test) {
  $ok = $false
  try { $ok = [bool](& $test) } catch { }
  if ($ok) { Write-Host "ok   $name" } else { Write-Host "FAIL $name"; $script:fails++ }
}
function Wait-For($path) {
  for ($i = 0; $i -lt 100; $i++) { if (Test-Path -LiteralPath $path) { return }; Start-Sleep -Milliseconds 100 }
}
function Read-Out($path) { Get-Content -LiteralPath $path -Raw }
function Start-Window($out, $sleep) {
  $env:FAKE_OUT = $out
  $env:FAKE_SLEEP = $sleep
  Start-Process -FilePath $shim -PassThru -WindowStyle Hidden
}

# 1. First window gets the first colour, second window gets the next.
$a = Start-Window "$tmp\a" 4
Wait-For "$tmp\a"
$b = Start-Window "$tmp\b" 4
Wait-For "$tmp\b"
Check 'first window is coral'   { (Read-Out "$tmp\a") -match 'colour=crab-coral' }
Check 'second window is orange' { (Read-Out "$tmp\b") -match 'colour=crab-orange' }
Check 'theme passed through settings' { (Read-Out "$tmp\a") -match '"theme":\s*"custom:crab-coral"' }
Check 'status line wired in'    { (Read-Out "$tmp\a") -match 'chroma-crab-statusline\.ps1' }
Check 'claim file exists while open' { Test-Path "$state\crab-coral.pid" }
$a.WaitForExit(); $b.WaitForExit()
Check 'claim released on exit'  { -not (Test-Path "$state\crab-coral.pid") }

# 2. A claim left by a crashed window gets reclaimed.
Set-Content -LiteralPath "$state\crab-coral.pid" -Value '999999 0'
$env:FAKE_SLEEP = $null
$env:FAKE_OUT = "$tmp\c"; & $shim
Check 'stale claim reclaimed'   { (Read-Out "$tmp\c") -match 'colour=crab-coral' }

# 3. A live process with the same PID but a different start time (PID reuse).
Set-Content -LiteralPath "$state\crab-coral.pid" -Value "$PID 12345"
$env:FAKE_OUT = "$tmp\d"; & $shim
Check 'reused PID not trusted'  { (Read-Out "$tmp\d") -match 'colour=crab-coral' }

# 4. Arguments and the exit code come through.
& $shim --fail
Check 'args and exit code passed through' { $LASTEXITCODE -eq 7 }
$settings = Get-Content -LiteralPath "$state\crab-coral.settings.json" -Raw | ConvertFrom-Json

# 5. Status line can be turned off.
$env:CHROMA_CRAB_STATUSLINE = '0'; $env:FAKE_OUT = "$tmp\f"; & $shim; $env:CHROMA_CRAB_STATUSLINE = $null
Check 'status line opt-out'     { (Read-Out "$tmp\f") -notmatch 'statusLine' }

# 6. The claude.exe stand-in, built the way install.ps1 builds it and put
#    first on PATH. Plain `claude` must reach chroma-crab and then the real
#    (fake) claude behind it, however it's launched.
New-Item -ItemType Directory -Force -Path "$app\shim" | Out-Null
& powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Add-Type -TypeDefinition (Get-Content -Raw -LiteralPath '$repo\windows\claude-shim.cs') -OutputAssembly '$app\shim\claude.exe' -OutputType ConsoleApplication"
Check 'stand-in builds' { Test-Path "$app\shim\claude.exe" }
$plainPath = $env:Path
$env:Path = "$app\shim;$plainPath"
function First-Line($path) { ((Get-Content -LiteralPath $path) | Select-Object -First 1).Trim() }

$env:FAKE_OUT = "$tmp\s1"; cmd /c claude --resume
Check 'claude from cmd gets a colour'      { (Read-Out "$tmp\s1") -match 'colour=crab-coral' }
Check 'arguments pass through'             { (First-Line "$tmp\s1") -match '^args=--settings .* --resume$' }
$env:FAKE_OUT = "$tmp\s2"; & claude
Check 'claude from PowerShell gets a colour' { (Read-Out "$tmp\s2") -match 'colour=crab-coral' }
$env:FAKE_OUT = "$tmp\s3"
$psi = New-Object System.Diagnostics.ProcessStartInfo 'claude', '--continue'
$psi.UseShellExecute = $false
$p = [System.Diagnostics.Process]::Start($psi); $p.WaitForExit()
Check 'direct launch (like a Terminal profile) gets a colour' { (Read-Out "$tmp\s3") -match 'colour=crab-coral' }
$env:FAKE_OUT = "$tmp\s4"; cmd /c claude mcp list
Check 'subcommands skip the colour'        { (First-Line "$tmp\s4") -eq 'args=mcp list' }
$env:FAKE_OUT = "$tmp\s5"; cmd /c claude -p "hello there"
Check 'print mode skips the colour'        { (First-Line "$tmp\s5") -eq 'args=-p "hello there"' }
$env:CHROMA_CRAB_ACTIVE = '1'; $env:FAKE_OUT = "$tmp\s6"; cmd /c claude; $env:CHROMA_CRAB_ACTIVE = $null
Check 'nested claude skips the colour'     { (First-Line "$tmp\s6") -eq 'args=' }
cmd /c claude --fail
Check 'exit code passes through the stand-in' { $LASTEXITCODE -eq 7 }
Check 'no claims left behind'              { @(Get-ChildItem "$state\*.pid").Count -eq 0 }
$env:Path = $plainPath

# 7. Status line output, run the way Claude Code runs it: JSON on stdin.
function Invoke-StatusLine($json, $colour) {
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = (Get-Process -Id $PID).Path
  $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$app\chroma-crab-statusline.ps1`""
  $psi.UseShellExecute = $false
  $psi.RedirectStandardInput = $true
  $psi.RedirectStandardOutput = $true
  $psi.StandardOutputEncoding = New-Object System.Text.UTF8Encoding $false
  $psi.EnvironmentVariables['CHROMA_CRAB_COLOUR'] = $colour
  $p = [System.Diagnostics.Process]::Start($psi)
  $in = New-Object System.IO.StreamWriter($p.StandardInput.BaseStream, (New-Object System.Text.UTF8Encoding $false))
  $in.Write($json); $in.Close()
  $out = $p.StandardOutput.ReadToEnd()
  $p.WaitForExit()
  return $out
}
$esc = [char]27
$payload = '{"model":{"display_name":"Opus"},"workspace":{"current_dir":"C:\\x\\proj\\sub","project_dir":"C:\\x\\proj"},"context_window":{"total_input_tokens":84000,"context_window_size":200000,"used_percentage":42},"cost":{"total_cost_usd":1.5}}'
$out = Invoke-StatusLine $payload 'crab-teal'
$plain = $out -replace "$esc\[[0-9;]*m", ''
Check 'settings command runs PowerShell' { $settings.statusLine.command -match '-File' }
Check 'bar uses the crab colour' { $out.Contains("$esc[38;2;115;218;202m") }
Check 'shows percentage'        { $plain.Contains('42%') }
Check 'shows tokens'            { $plain.Contains('84k/200k') }
Check 'shows project/subdir'    { $plain.Contains('proj/sub') }
Check 'shows cost'              { $plain.Contains('$1.50') }
# 42% of 20 cells is 8 full cells and three eighths of the ninth.
$expectBar = [string][char]0x2595 + ([string][char]0x2588 * 8) + [char]0x258D + ([string][char]0x2591 * 11) + [char]0x258F
Check 'bar is 20 cells, filled to 42%' { $plain.Contains($expectBar) }
$hot = Invoke-StatusLine '{"context_window":{"used_percentage":95,"context_window_size":200000}}' ''
Check 'turns red near the limit' { $hot.Contains("$esc[38;2;247;118;142m95%") }

Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
Write-Host ''
if ($script:fails -eq 0) { Write-Host 'all passed' } else { Write-Host "$($script:fails) failed"; exit 1 }
