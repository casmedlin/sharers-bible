#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Sharer's Bible App"
APP="build/${APP_NAME}.app"
DMG="build/${APP_NAME}.dmg"
EXEC="${APP}/Contents/MacOS/${APP_NAME}"
RES="${APP}/Contents/Resources"
BIBLES="$(cd ../bibles && pwd)"

SDK=$(xcrun --sdk macosx --show-sdk-path)

echo "=== Building ${APP_NAME} ==="
mkdir -p "${APP}/Contents/MacOS" "${RES}"

xcrun swiftc -sdk "$SDK" -parse-as-library \
  -o "${EXEC}" \
  -Xlinker -rpath -Xlinker /usr/lib/swift \
  ContentView.swift

cp -R "$BIBLES" "${RES}/bibles"
echo "Build complete."

echo "=== Creating DMG ==="
rm -rf build/dmg-tmp "$DMG"
mkdir -p build/dmg-tmp
cp -R "$APP" build/dmg-tmp/
ln -s /Applications build/dmg-tmp/Applications

SIZE=$(du -sm build/dmg-tmp | cut -f1)
SIZE=$((SIZE + 15))

hdiutil create -fs HFS+ -srcfolder build/dmg-tmp \
  -volname "${APP_NAME}" \
  -format UDZO -imagekey zlib-level=9 \
  -size ${SIZE}m "$DMG"

rm -rf build/dmg-tmp

echo "=== Created $(pwd)/${DMG} ==="
echo "Users can open the DMG and drag ${APP_NAME}.app to Applications."
