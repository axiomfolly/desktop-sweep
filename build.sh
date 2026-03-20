#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Desktop Sweep"
EXECUTABLE="DesktopSweep"
BUILD_DIR="$SCRIPT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"

ARCH="$(uname -m)"
if [[ "$ARCH" == "arm64" ]]; then
    TARGET="arm64-apple-macos13.0"
else
    TARGET="x86_64-apple-macos13.0"
fi

SDK="$(xcrun --show-sdk-path)"

SOURCES=(
    "$SCRIPT_DIR/DesktopSweep/DesktopSweepApp.swift"
    "$SCRIPT_DIR/DesktopSweep/Views/SettingsView.swift"
    "$SCRIPT_DIR/DesktopSweep/Views/SkipListEditor.swift"
    "$SCRIPT_DIR/DesktopSweep/Models/SweepConfig.swift"
    "$SCRIPT_DIR/DesktopSweep/Services/ScriptRunner.swift"
    "$SCRIPT_DIR/DesktopSweep/Services/LaunchdManager.swift"
)

echo "Building $APP_NAME ($ARCH)..."

rm -rf "$BUILD_DIR"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

swiftc \
    -target "$TARGET" \
    -sdk "$SDK" \
    -framework SwiftUI \
    -framework AppKit \
    -framework Combine \
    -parse-as-library \
    -O \
    -o "$CONTENTS/MacOS/$EXECUTABLE" \
    "${SOURCES[@]}"

cp "$SCRIPT_DIR/DesktopSweep/Info.plist" "$CONTENTS/Info.plist"
cp "$SCRIPT_DIR/DesktopSweep/AppIcon.icns" "$CONTENTS/Resources/AppIcon.icns"
cp "$SCRIPT_DIR/archive-desktop.sh" "$CONTENTS/Resources/"
cp "$SCRIPT_DIR/config.cfg" "$CONTENTS/Resources/"
chmod +x "$CONTENTS/Resources/archive-desktop.sh"

echo ""
echo "Build complete: $APP_BUNDLE"
echo ""
echo "To run:     open \"$APP_BUNDLE\""
echo "To install: cp -R \"$APP_BUNDLE\" /Applications/"
