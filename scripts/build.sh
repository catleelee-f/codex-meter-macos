#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="CodexMeter"
BUILD_DIR="$PROJECT_DIR/outputs/build"
APP_DIR="$PROJECT_DIR/outputs/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

mkdir -p "$BUILD_DIR" "$MACOS_DIR" "$RESOURCES_DIR"

ICON_MODULE_CACHE_DIR="$BUILD_DIR/module-cache-icon"
mkdir -p "$ICON_MODULE_CACHE_DIR"
CLANG_MODULE_CACHE_PATH="$ICON_MODULE_CACHE_DIR" \
SWIFT_MODULE_CACHE_PATH="$ICON_MODULE_CACHE_DIR" \
xcrun swiftc \
  -O \
  -swift-version 5 \
  -module-cache-path "$ICON_MODULE_CACHE_DIR" \
  -framework AppKit \
  "$PROJECT_DIR/scripts/generate-icon.swift" \
  -o "$BUILD_DIR/generate-icon"
"$BUILD_DIR/generate-icon" "$PROJECT_DIR/assets"

SOURCES=(
  "$PROJECT_DIR/source/Models.swift"
  "$PROJECT_DIR/source/CodexLogScanner.swift"
  "$PROJECT_DIR/source/CodexAccountUsageClient.swift"
  "$PROJECT_DIR/source/UsageStore.swift"
  "$PROJECT_DIR/source/DashboardViews.swift"
  "$PROJECT_DIR/source/DetailsView.swift"
  "$PROJECT_DIR/source/AppDelegate.swift"
)

for ARCH in arm64 x86_64; do
  MODULE_CACHE_DIR="$BUILD_DIR/module-cache-$ARCH"
  mkdir -p "$MODULE_CACHE_DIR"

  CLANG_MODULE_CACHE_PATH="$MODULE_CACHE_DIR" \
  SWIFT_MODULE_CACHE_PATH="$MODULE_CACHE_DIR" \
  xcrun swiftc \
    -O \
    -swift-version 5 \
    -target "$ARCH-apple-macos13.0" \
    -module-cache-path "$MODULE_CACHE_DIR" \
    -framework AppKit \
    -framework Combine \
    -framework Foundation \
    -framework SwiftUI \
    "${SOURCES[@]}" \
    -o "$BUILD_DIR/$APP_NAME-$ARCH"
done

lipo -create \
  "$BUILD_DIR/$APP_NAME-arm64" \
  "$BUILD_DIR/$APP_NAME-x86_64" \
  -output "$MACOS_DIR/$APP_NAME"

cp "$PROJECT_DIR/source/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$PROJECT_DIR/assets/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
codesign --force --deep --sign - "$APP_DIR" >/dev/null

ditto -c -k --sequesterRsrc --keepParent \
  "$APP_DIR" \
  "$PROJECT_DIR/outputs/$APP_NAME-macOS-universal.zip"

echo "$APP_DIR"
echo "$PROJECT_DIR/outputs/$APP_NAME-macOS-universal.zip"
