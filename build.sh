#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP="build/HeartEyes.app"
MACOS="$APP/Contents/MacOS"
RES="$APP/Contents/Resources"

VERSION="${HEARTEYES_VERSION:-1.0.0}"
SIGN_ID="${MACOS_SIGN_IDENTITY:--}"

SRC=(Sources/RestLedger.swift Sources/ReflectionWindow.swift Sources/main.swift)
FRAMEWORKS=(-framework Cocoa -framework CoreAudio -framework IOKit
  -framework ServiceManagement -framework UniformTypeIdentifiers)

echo "› Cleaning…"
rm -rf build
mkdir -p "$MACOS" "$RES"

build_slice () {
  local arch="$1" out="$2"
  echo "  · $arch"
  swiftc -O -swift-version 5 \
    -target "${arch}-apple-macos13.0" \
    "${SRC[@]}" \
    -o "$out" \
    "${FRAMEWORKS[@]}"
}

echo "› Compiling (Swift, optimized, universal)…"
build_slice arm64  "build/HeartEyes-arm64"
build_slice x86_64 "build/HeartEyes-x86_64"

echo "› Merging slices into a universal binary…"
lipo -create -output "$MACOS/HeartEyes" \
  "build/HeartEyes-arm64" "build/HeartEyes-x86_64"
rm -f "build/HeartEyes-arm64" "build/HeartEyes-x86_64"

echo "› Writing Info.plist (version $VERSION)…"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>              <string>HeartEyes</string>
  <key>CFBundleDisplayName</key>       <string>HeartEyes</string>
  <key>CFBundleIdentifier</key>        <string>com.aashish.hearteyes</string>
  <key>CFBundleExecutable</key>        <string>HeartEyes</string>
  <key>CFBundlePackageType</key>       <string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key>           <string>$VERSION</string>
  <key>LSMinimumSystemVersion</key>    <string>13.0</string>
  <key>LSUIElement</key>               <true/>
  <key>NSHighResolutionCapable</key>   <true/>
</dict>
</plist>
PLIST

if [ "$SIGN_ID" = "-" ]; then
  echo "› Code-signing (ad-hoc)…"
  codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
else
  echo "› Code-signing (Developer ID, hardened runtime)…"
  codesign --force --deep --options runtime --timestamp \
    --sign "$SIGN_ID" "$APP"
fi

echo ""
echo "✓ Built $APP  ($(lipo -archs "$MACOS/HeartEyes"))"
echo "  Run it:   open \"$APP\""
echo "  Install:  cp -R \"$APP\" /Applications/"
