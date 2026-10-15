#!/bin/zsh
# Builds Spooterfy.app into ./build. Pass --install to copy it to /Applications.
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

if [[ "${1:-}" == "--install" ]]; then
  rm -rf /Applications/Spooterfy.app
  cp -R "$APP" /Applications/
  echo "Installed /Applications/Spooterfy.app"
fi
