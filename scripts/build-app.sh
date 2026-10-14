#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
binary_dir=$(swift build -c release --show-bin-path)
app="build/MacGlint.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary_dir/MacGlint" "$app/Contents/MacOS/MacGlint"
cp Resources/Info.plist "$app/Contents/Info.plist"
swift scripts/make-icon.swift build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o "$app/Contents/Resources/AppIcon.icns"
plutil -lint "$app/Contents/Info.plist"
codesign --force --sign - "$app"
codesign --verify --strict "$app"
echo "Built: $PWD/$app (local ad-hoc signature; not notarized)"
