#!/bin/bash
# Regenerates Resources/AppIcon.icns and docs/icon.png from scripts/make-icon.swift.
set -euo pipefail
cd "$(dirname "$0")/.."
BIN="$(mktemp -d)/make-icon"
swiftc -O scripts/make-icon.swift -o "$BIN" 2>&1 | grep -v CompatibilityPacks || true
"$BIN"
