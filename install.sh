#!/usr/bin/env bash
# Install claude-crab on macOS or Linux.
#
#   ./install.sh            install claude-crab and claude-statusline
#   ./install.sh --alias    also make plain `claude` pick a colour
#
# BIN_DIR defaults to ~/.local/bin. Themes go to ~/.claude/themes
# (or $CLAUDE_CONFIG_DIR/themes).

set -eu

src="$(cd "$(dirname "$0")" && pwd)"
bin_dir="${BIN_DIR:-$HOME/.local/bin}"
theme_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/themes"
alias=0
[ "${1:-}" = "--alias" ] && alias=1

mkdir -p "$bin_dir" "$theme_dir"
cp "$src/bin/claude-crab" "$src/bin/claude-statusline" "$bin_dir/"
chmod +x "$bin_dir/claude-crab" "$bin_dir/claude-statusline"
cp "$src"/themes/crab-*.json "$theme_dir/"
echo "Installed claude-crab and claude-statusline to $bin_dir"
echo "Installed $(ls "$src"/themes/crab-*.json | wc -l | tr -d ' ') crab themes to $theme_dir"

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

if [ "$alias" = 1 ]; then
  case "${SHELL##*/}" in
    zsh) rc="$HOME/.zshrc" ;;
    *)   rc="$HOME/.bashrc" ;;
  esac
  if grep -q 'claude-crab' "$rc" 2>/dev/null; then
    echo "$rc already mentions claude-crab, leaving it alone."
  else
    printf '\n# claude-crab: give every Claude Code window its own crab colour\nalias claude=claude-crab\n' >> "$rc"
    echo "Added 'alias claude=claude-crab' to $rc. Open a new terminal to use it."
  fi
fi
