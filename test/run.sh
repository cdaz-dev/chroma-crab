#!/usr/bin/env bash
# Tests for the macOS/Linux scripts. Uses a fake `claude` that records how it
# was called, so no Claude Code install or login is needed.
set -u

repo="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export XDG_STATE_HOME="$tmp/state"
export CLAUDE_CONFIG_DIR="$tmp/config"
mkdir -p "$tmp/fake" "$CLAUDE_CONFIG_DIR/themes"
cp "$repo"/themes/crab-*.json "$CLAUDE_CONFIG_DIR/themes/"

# Fake claude: write its arguments, the settings file it was given and the
# exported colour, then stay open for FAKE_SLEEP seconds like a real session.
cat > "$tmp/fake/claude" <<'EOF'
#!/usr/bin/env bash
{ echo "args=$*"
  [ "${1:-}" = --settings ] && cat "$2"
  echo "colour=${CHROMA_CRAB_COLOUR:-none}"; } > "$FAKE_OUT"
case " $* " in *" --fail "*) exit 7 ;; esac
sleep "${FAKE_SLEEP:-0}"
EOF
chmod +x "$tmp/fake/claude"
export PATH="$tmp/fake:$PATH"

fails=0
check() { # description, command...
  if "${@:2}"; then echo "ok   $1"; else echo "FAIL $1"; fails=$((fails + 1)); fi
}
state="$XDG_STATE_HOME/chroma-crab"
wait_for() { for _ in $(seq 50); do [ -e "$1" ] && return 0; sleep 0.1; done; return 1; }

# 1. First window gets the first colour, second window gets the next.
FAKE_OUT="$tmp/a" FAKE_SLEEP=3 "$repo/bin/chroma-crab" & a=$!
wait_for "$tmp/a"
FAKE_OUT="$tmp/b" FAKE_SLEEP=3 "$repo/bin/chroma-crab" & b=$!
wait_for "$tmp/b"
check "first window is coral"   grep -q 'colour=crab-coral'  "$tmp/a"
check "second window is orange" grep -q 'colour=crab-orange' "$tmp/b"
check "theme passed through settings" grep -q '"theme":"custom:crab-coral"' "$tmp/a"
check "status line wired in"    grep -q 'chroma-crab-statusline' "$tmp/a"
check "claim file exists while open" test -e "$state/crab-coral.pid"
wait "$a" "$b"
check "claim released on exit"  test ! -e "$state/crab-coral.pid"

# 2. A claim left by a crashed window gets reclaimed.
echo 999999 > "$state/crab-coral.pid"
FAKE_OUT="$tmp/c" "$repo/bin/chroma-crab"
check "stale claim reclaimed"   grep -q 'colour=crab-coral' "$tmp/c"

# 3. A live process that isn't chroma-crab doesn't hold a colour (PID reuse).
sleep 5 & other=$!
echo "$other" > "$state/crab-coral.pid"
FAKE_OUT="$tmp/d" "$repo/bin/chroma-crab"
check "reused PID not trusted"  grep -q 'colour=crab-coral' "$tmp/d"
kill "$other" 2>/dev/null

# 4. Status line can be turned off.
CHROMA_CRAB_STATUSLINE=0 FAKE_OUT="$tmp/e" "$repo/bin/chroma-crab"
check "status line opt-out"     bash -c "! grep -q statusLine '$tmp/e'"

# 5. The claude stand-in that install.sh writes, first on PATH. Running plain
#    `claude` must reach chroma-crab and then the real (fake) claude behind it.
mkdir -p "$tmp/shim"
printf '#!/bin/sh\n# chroma-crab-shim: test copy\nexec "%s" "$@"\n' "$repo/bin/chroma-crab" > "$tmp/shim/claude"
chmod +x "$tmp/shim/claude"
shimmed() { PATH="$tmp/shim:$PATH" "$@"; }
FAKE_OUT="$tmp/s1" shimmed claude --resume
check "plain claude gets a colour"     grep -q 'colour=crab-coral' "$tmp/s1"
check "arguments pass through"         grep -q 'args=--settings .* --resume' "$tmp/s1"
FAKE_OUT="$tmp/s2" shimmed claude mcp list
check "subcommands skip the colour"    grep -qx 'args=mcp list' "$tmp/s2"
FAKE_OUT="$tmp/s3" shimmed claude -p "hello there"
check "print mode skips the colour"    grep -qx 'args=-p hello there' "$tmp/s3"
FAKE_OUT="$tmp/s4" CHROMA_CRAB_ACTIVE=1 shimmed claude
check "nested claude skips the colour" grep -qx 'args=' "$tmp/s4"
FAKE_OUT="$tmp/s5" shimmed claude --fail; code=$?
check "exit code passes through"       test "$code" = 7
check "no claims left behind"          test -z "$(ls "$state"/*.pid 2>/dev/null)"

# 6. Status line output.
payload='{"model":{"display_name":"Opus"},"workspace":{"current_dir":"/x/proj/sub","project_dir":"/x/proj"},
"context_window":{"total_input_tokens":84000,"context_window_size":200000,"used_percentage":42},"cost":{"total_cost_usd":1.5}}'
out="$(printf '%s' "$payload" | CHROMA_CRAB_COLOUR=crab-teal "$repo/bin/chroma-crab-statusline")"
check "bar uses the crab colour" grep -q $'\033\\[38;2;115;218;202m' <<<"$out"
check "shows percentage"        grep -q '42%' <<<"$out"
check "shows tokens"            grep -q '84k/200k' <<<"$out"
check "shows project/subdir"    grep -q 'proj/sub' <<<"$out"
check "shows cost"              grep -q '\$1.50' <<<"$out"
# 42% of 20 cells is 8 full cells and three eighths of the ninth.
plain="$(printf '%s' "$out" | sed $'s/\033\\[[0-9;]*m//g')"
check "bar is 20 cells, filled to 42%" grep -qF '▕████████▍░░░░░░░░░░░▏' <<<"$plain"
hot="$(printf '%s' '{"context_window":{"used_percentage":95,"context_window_size":200000}}' | "$repo/bin/chroma-crab-statusline")"
check "turns red near the limit" grep -q $'\033\\[38;2;247;118;142m95%' <<<"$hot"

echo
[ "$fails" = 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }
