#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/build-app.sh
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)
arch=$(uname -m)
staging=$(mktemp -d "${TMPDIR:-/tmp}/macglint-dmg.XXXXXX")
trap 'rm -rf "$staging"' EXIT
cp -R build/MacGlint.app "$staging/MacGlint.app"
ln -s /Applications "$staging/Applications"
cat > "$staging/Read Me.txt" <<'NOTICE'
MacGlint — local preview
Drag MacGlint to Applications. Requires macOS 14 or later.
This source build is ad-hoc signed, not Apple-notarized.
Do not disable Gatekeeper. Public signed distribution is planned.
https://github.com/greenpandorik/macglint
NOTICE
hdiutil create -volname MacGlint -srcfolder "$staging" -ov -format UDZO "build/MacGlint-$version-$arch.dmg"
echo "Created: $PWD/build/MacGlint-$version-$arch.dmg"
