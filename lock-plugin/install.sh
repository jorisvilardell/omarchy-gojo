#!/bin/bash
set -euo pipefail

# Installs the Gojo lock screen permanently, without omatheme. It overlays the
# presentational files onto a fresh clone of Omarchy's own lock plugin, so
# Service.qml -- PAM, ext-session-lock-v1, retry and lockout -- keeps coming
# from your install and keeps receiving upstream fixes.

REPO_URL="https://github.com/jorisvilardell/omarchy-gojo.git"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-}")" 2>/dev/null && pwd || echo "")"

if [ -z "$SCRIPT_DIR" ] || [ ! -f "$SCRIPT_DIR/qml/LockView.qml" ]; then
  # Running via curl | bash -- no local clone to read from, so grab one.
  TMP_DIR=$(mktemp -d)
  trap 'rm -rf "$TMP_DIR"' EXIT
  git clone --depth 1 "$REPO_URL" "$TMP_DIR/repo" >/dev/null 2>&1
  exec bash "$TMP_DIR/repo/lock-plugin/install.sh"
fi

PLUGIN_DIR=$(find "$HOME/.config/omarchy/plugins" -maxdepth 1 -type d -name "*.lock" 2>/dev/null | head -n1)

if [ -n "$PLUGIN_DIR" ]; then
  echo "Lock plugin already cloned at $PLUGIN_DIR -- reusing it, not re-cloning."
else
  omarchy plugin clone omarchy.lock
  PLUGIN_DIR=$(find "$HOME/.config/omarchy/plugins" -maxdepth 1 -type d -name "*.lock" 2>/dev/null | head -n1)
fi

if [ -z "$PLUGIN_DIR" ]; then
  echo "error: no clone found under ~/.config/omarchy/plugins/*.lock" >&2
  exit 1
fi

cp -r "$SCRIPT_DIR"/qml/. "$PLUGIN_DIR/"

echo "Installed into $PLUGIN_DIR"
echo "(Service.qml there is Omarchy's own file -- this script never touches it.)"
omarchy restart shell >/dev/null 2>&1 || echo "Run 'omarchy restart shell' to pick it up."
echo
echo "Try it: omarchy-system-lock"
echo "To go back to Omarchy's own lock screen: ./lock-plugin/uninstall.sh"
