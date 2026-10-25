#!/usr/bin/env bash
# Install chroma-crab on macOS or Linux.
#
#   ./install.sh              install, and make `claude` itself pick a colour
#   ./install.sh --no-shim    install the chroma-crab command only
#   ./install.sh --uninstall  remove everything this script added
#
# BIN_DIR defaults to ~/.local/bin. Themes go to ~/.claude/themes
# (or $CLAUDE_CONFIG_DIR/themes).

set -eu

src="$(cd "$(dirname "$0")" && pwd)"
bin_dir="${BIN_DIR:-$HOME/.local/bin}"
theme_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/themes"
shim_dir="$HOME/.local/share/chroma-crab/bin"
envd="${XDG_CONFIG_HOME:-$HOME/.config}/environment.d/60-chroma-crab.conf"
mode="${1:-install}"

# Every line this script adds to a startup file ends in this tag, so
# --uninstall can find them again.
tag="# chroma-crab"
path_line="export PATH=\"$shim_dir:\$PATH\" $tag"

strip_lines() { # file
  [ -f "$1" ] && grep -q "$tag\$" "$1" || return 0
  { grep -v "$tag\$" "$1" || true; } > "$1.chroma-crab.tmp"
  cat "$1.chroma-crab.tmp" > "$1"
  rm -f "$1.chroma-crab.tmp"
}

rc_files() {
  for f in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.zshenv" "$HOME/.profile" "$HOME/.bash_profile" "$HOME/.zprofile"; do
    [ -f "$f" ] && echo "$f"
  done
  # Make sure the current shell's rc is covered even if it doesn't exist yet.
  # zsh -c (how many macOS hotkey tools run commands) only reads .zshenv.
  case "${SHELL##*/}" in
    zsh)  [ -f "$HOME/.zshrc" ]  || echo "$HOME/.zshrc"
          [ -f "$HOME/.zshenv" ] || echo "$HOME/.zshenv" ;;
    bash) [ -f "$HOME/.bashrc" ] || echo "$HOME/.bashrc" ;;
  esac
}

if [ "$mode" = "--uninstall" ]; then
  rm -f "$bin_dir/chroma-crab" "$bin_dir/chroma-crab-statusline" "$theme_dir"/crab-*.json "$envd"
  rm -rf "$HOME/.local/share/chroma-crab"
  for f in $(rc_files); do strip_lines "$f"; done
  echo "Removed chroma-crab. Open a new terminal (or log out and in) to drop it from PATH."
  exit 0
fi

mkdir -p "$bin_dir" "$theme_dir"
cp "$src/bin/chroma-crab" "$src/bin/chroma-crab-statusline" "$bin_dir/"
chmod +x "$bin_dir/chroma-crab" "$bin_dir/chroma-crab-statusline"
cp "$src"/themes/crab-*.json "$theme_dir/"
echo "Installed chroma-crab and chroma-crab-statusline to $bin_dir"
echo "Installed $(ls "$src"/themes/crab-*.json | wc -l | tr -d ' ') crab themes to $theme_dir"

if [ "$mode" != "--no-shim" ]; then
  # A stand-in named `claude`, placed ahead of the real one on PATH. Anything
  # that runs claude by name (your shell, a keybind, a terminal profile, a
  # launcher) goes through chroma-crab without any change on your side.
  mkdir -p "$shim_dir"
  cat > "$shim_dir/claude" <<EOF
#!/bin/sh
# chroma-crab-shim: stands in for claude so it gets a crab colour.
exec "$bin_dir/chroma-crab" "\$@"
EOF
  chmod +x "$shim_dir/claude"

  for f in $(rc_files); do
    strip_lines "$f"
    printf '%s\n' "$path_line" >> "$f"
  done
  echo "Put $shim_dir first on PATH in: $(rc_files | tr '\n' ' ')"

  # Desktop sessions on most modern Linux setups read environment.d, which is
  # where keybinds get their PATH from.
  if [ "$(uname -s)" = Linux ]; then
    mkdir -p "$(dirname "$envd")"
    printf 'PATH=%s:${PATH}\n' "$shim_dir" > "$envd"
    echo "Put $shim_dir first on the desktop session PATH ($envd)"
  fi
  echo
  echo "Open a new terminal to use it. For keybinds, log out and back in once."
fi

if ! command -v jq >/dev/null 2>&1; then
  echo
  echo "The status line needs jq and it isn't installed."
  echo "  macOS:  brew install jq"
  echo "  Linux:  your package manager, e.g. sudo apt install jq"
fi

case ":$PATH:" in
  *":$bin_dir:"*) ;;
  *) echo; echo "$bin_dir is not on your PATH. Add this to your shell rc:"
     echo "  export PATH=\"$bin_dir:\$PATH\"" ;;
esac
