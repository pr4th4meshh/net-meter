#!/bin/bash
# Installs the latest NetMeter release into /Applications and opens it.
#   curl -fsSL https://raw.githubusercontent.com/pr4th4meshh/net-meter/main/install.sh | bash
set -euo pipefail

REPO="pr4th4meshh/net-meter"
URL="https://github.com/$REPO/releases/latest/download/NetMeter.zip"
DEST="${NETMETER_DIR:-/Applications}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading NetMeter..."
curl -fsSL "$URL" -o "$TMP/NetMeter.zip"
ditto -x -k "$TMP/NetMeter.zip" "$TMP"

# Fall back to ~/Applications if /Applications isn't writable (non-admin users).
if [ ! -w "$DEST" ]; then
    DEST="$HOME/Applications"
    mkdir -p "$DEST"
fi

pkill -x NetMeter 2>/dev/null || true
rm -rf "$DEST/NetMeter.app"
ditto "$TMP/NetMeter.app" "$DEST/NetMeter.app"
xattr -dr com.apple.quarantine "$DEST/NetMeter.app" 2>/dev/null || true

open "$DEST/NetMeter.app"
echo "Installed to $DEST/NetMeter.app. Look for the speed in your menu bar."
