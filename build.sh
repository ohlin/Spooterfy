#!/bin/zsh
# Builds Spooterfy.app into ./build.
#   --install  also copies it to /Applications
#   --dmg      also makes build/Spooterfy-<version>.dmg for a GitHub release
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Spooterfy"

APP=build/Spooterfy.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Spooterfy"
cp Resources/Info.plist "$APP/Contents/Info.plist"
# Icon Composer file -> Assets.car (Liquid Glass icon) + spooterfy.icns (fallback).
xcrun actool Resources/spooterfy.icon --compile "$APP/Contents/Resources" \
  --platform macosx --minimum-deployment-target 26.0 --app-icon spooterfy \
  --output-partial-info-plist build/icon-partial.plist >/dev/null
cp -R Resources/Fonts "$APP/Contents/Resources/Fonts"
codesign --force --sign - "$APP"
echo "Built $APP"

if [[ "${1:-}" == "--dmg" ]]; then
  VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
  DMG="build/Spooterfy-$VERSION.dmg"
  STAGE=build/dmg
  rm -rf "$STAGE" "$DMG"
  mkdir -p "$STAGE"
  cp -R "$APP" "$STAGE/"
  ln -s /Applications "$STAGE/Applications"   # drag-to-install target
  hdiutil create -volname "Spooterfy" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
  rm -rf "$STAGE"
  echo "Built $DMG"
fi

if [[ "${1:-}" == "--install" ]]; then
  rm -rf /Applications/Spooterfy.app
  cp -R "$APP" /Applications/
  echo "Installed /Applications/Spooterfy.app"
fi
