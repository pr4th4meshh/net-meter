#!/bin/bash
# Builds NetMeter.app into ./build. Needs only the Xcode Command Line Tools:
#   xcode-select --install
set -euo pipefail
cd "$(dirname "$0")"

APP="build/NetMeter.app"
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Resources/Info.plist "$APP/Contents/Info.plist"

SOURCES=(Sources/NetMeter/*.swift)
FLAGS=(-O -swift-version 5 -framework AppKit -framework ServiceManagement)

echo "Compiling (Apple Silicon)..."
swiftc "${FLAGS[@]}" -target arm64-apple-macos13.0  "${SOURCES[@]}" -o build/NetMeter-arm64
echo "Compiling (Intel)..."
swiftc "${FLAGS[@]}" -target x86_64-apple-macos13.0 "${SOURCES[@]}" -o build/NetMeter-x86_64

lipo -create build/NetMeter-arm64 build/NetMeter-x86_64 -output "$APP/Contents/MacOS/NetMeter"
rm build/NetMeter-arm64 build/NetMeter-x86_64

# Ad-hoc signature (free, no Apple Developer account needed)
codesign --force --deep --sign - "$APP"

echo ""
echo "Built $APP"
echo "Run it:      open $APP"
echo "Install it:  cp -R $APP /Applications/"
