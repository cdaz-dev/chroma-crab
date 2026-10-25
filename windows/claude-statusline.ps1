# Claude Code status line: a visual context-window gauge. Windows version of
# bin/claude-statusline. Works in Windows PowerShell 5.1 and PowerShell 7.
#
# Reads the status-line JSON on stdin and prints one line. The bar is tinted
# with this window's crab colour, so the gauge doubles as the window identity
# marker. See claude-crab.ps1.
#
# Every non-ASCII character is built from its code point, because Windows
# PowerShell 5.1 reads a BOM-less script file as ANSI and would garble them.

$utf8 = New-Object System.Text.UTF8Encoding $false
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$inv = [System.Globalization.CultureInfo]::InvariantCulture

# Windows PowerShell 5.1 hands piped stdin to the script as $input and leaves
# [Console]::In empty. PowerShell 7 does the opposite. Try both.
$payload = ($input | Out-String)
if (-not $payload.Trim()) { $payload = [Console]::In.ReadToEnd() }
if ($env:CLAUDE_STATUSLINE_DEBUG -eq '1') {
  [System.IO.File]::WriteAllText((Join-Path $HOME '.claude-statusline.json'), $payload)
}
try { $j = $payload | ConvertFrom-Json } catch { $j = $null }

function Get-Field($obj, [string[]]$path, $default) {
  foreach ($k in $path) {
    if ($null -eq $obj) { return $default }
    $obj = $obj.$k
  }
  if ($null -eq $obj) { return $default }
  return $obj
}

$model   = [string](Get-Field $j @('model', 'display_name') 'claude')
$cwd     = [string](Get-Field $j @('workspace', 'current_dir') '')
$projdir = [string](Get-Field $j @('workspace', 'project_dir') '')
$used    = [double](Get-Field $j @('context_window', 'total_input_tokens') 0)
$total   = [double](Get-Field $j @('context_window', 'context_window_size') 0)
$pctRaw  = [double](Get-Field $j @('context_window', 'used_percentage') -1)
$cost    = [double](Get-Field $j @('cost', 'total_cost_usd') 0)

# Percentage: prefer the value Claude Code computes, fall back to raw division.
if ($pctRaw -ge 0) { $pct = $pctRaw } elseif ($total -gt 0) { $pct = $used * 100 / $total } else { $pct = 0 }
$pct = [Math]::Min(100, [Math]::Max(0, $pct))
$pctText = [Math]::Round($pct).ToString($inv)

function Format-Tokens([double]$n) {
  if ($n -ge 1000000) { return ($n / 1000000).ToString('0.0', $inv) + 'M' }
  if ($n -ge 1000) { return [Math]::Round($n / 1000).ToString($inv) + 'k' }
  return [Math]::Round($n).ToString($inv)
}

# --- colours ---------------------------------------------------------------
# The crab slug is exported by claude-crab; look its hex up in the theme file
# so adding a new crab colour needs no change here.
$crabHex = '#7aa2f7'
$slug = $env:CLAUDE_CRAB_COLOUR
$config = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME '.claude' }
if ($slug) {
  $themeFile = Join-Path $config "themes\$slug.json"
  if (Test-Path -LiteralPath $themeFile) {
    try {
      $h = (Get-Content -LiteralPath $themeFile -Raw | ConvertFrom-Json).overrides.clawd_body
      if ($h) { $crabHex = $h }
    } catch { }
  }
}

$esc = [char]27
function Get-Ansi([string]$hex) { # #rrggbb -> SGR truecolour foreground
  $x = $hex.TrimStart('#')
  $r = [Convert]::ToInt32($x.Substring(0, 2), 16)
  $g = [Convert]::ToInt32($x.Substring(2, 2), 16)
  $b = [Convert]::ToInt32($x.Substring(4, 2), 16)
  return "$esc[38;2;$r;$g;${b}m"
}

$cBar = Get-Ansi $crabHex
$cDim = Get-Ansi '#565f89'
$cTxt = Get-Ansi '#a9b1d6'
$reset = "$esc[0m"

# Pressure colour for the number: calm, then warn, then alarm.
if ($pct -ge 90) { $cPct = Get-Ansi '#f7768e' } elseif ($pct -ge 70) { $cPct = Get-Ansi '#e0af68' } else { $cPct = $cBar }

# --- bar -------------------------------------------------------------------
$fullBlock = [string][char]0x2588   # full block
$shade     = [string][char]0x2591   # light shade
$dot       = [string][char]0x00B7   # middle dot
$leftBar   = [string][char]0x258D   # left three-eighths block
$rightEdge = [string][char]0x2595   # right one-eighth block
$leftEdge  = [string][char]0x258F   # left one-eighth block

$width = 20
$eighths = [int][Math]::Floor($pct / 100 * $width * 8 + 0.5)
$full = [int][Math]::Floor($eighths / 8)
$rem = $eighths % 8
if ($full -gt $width) { $full = $width; $rem = 0 }

$bar = $fullBlock * $full
if ($rem -gt 0 -and $full -lt $width) {
  # U+258F (one eighth) down to U+2589 (seven eighths)
  $bar += [string][char](0x2590 - $rem)
  $full++
}
$empty = $shade * ($width - $full)

# --- path ------------------------------------------------------------------
$dir = if ($cwd) { $cwd } else { (Get-Location).Path }
$label = Split-Path -Leaf $dir
if ($projdir -and $dir -ne $projdir) { $label = (Split-Path -Leaf $projdir) + '/' + $label }

# --- assemble --------------------------------------------------------------
$line = "$cBar$leftBar$reset $cTxt$model$reset $cDim$dot$reset $cTxt$label$reset"
if ($total -gt 0) {
  $line += "  $cDim$rightEdge$reset$cBar$bar$reset$cDim$empty$leftEdge$reset "
  $line += "$cPct$pctText%$reset $cDim$(Format-Tokens $used)/$(Format-Tokens $total)$reset"
}
if ($cost -ge 0.01) {
  $line += "  $cDim`$" + $cost.ToString('0.00', $inv) + $reset
}

[Console]::Out.Write($line)
