#!/bin/bash
# Builds ByteBar.app into ./build. Needs only the Xcode Command Line Tools:
#   xcode-select --install
set -euo pipefail
cd "$(dirname "$0")"

APP="build/ByteBar.app"
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Resources/Info.plist "$APP/Contents/Info.plist"

SOURCES=(Sources/ByteBar/*.swift)
FLAGS=(-O -swift-version 5 -framework AppKit -framework ServiceManagement)

echo "Compiling (Apple Silicon)..."
swiftc "${FLAGS[@]}" -target arm64-apple-macos13.0  "${SOURCES[@]}" -o build/ByteBar-arm64
echo "Compiling (Intel)..."
swiftc "${FLAGS[@]}" -target x86_64-apple-macos13.0 "${SOURCES[@]}" -o build/ByteBar-x86_64

lipo -create build/ByteBar-arm64 build/ByteBar-x86_64 -output "$APP/Contents/MacOS/ByteBar"
rm build/ByteBar-arm64 build/ByteBar-x86_64

# Ad-hoc signature (free, no Apple Developer account needed)
codesign --force --deep --sign - "$APP"

echo ""
echo "Built $APP"
echo "Run it:      open $APP"
echo "Install it:  cp -R $APP /Applications/"
