#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Desktop Sweep"
EXECUTABLE="DesktopSweep"
BUILD_DIR="$SCRIPT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"

SDK="$(xcrun --show-sdk-path)"

SOURCES=(
    "$SCRIPT_DIR/DesktopSweep/DesktopSweepApp.swift"
    "$SCRIPT_DIR/DesktopSweep/Views/SettingsView.swift"
    "$SCRIPT_DIR/DesktopSweep/Views/SkipListEditor.swift"
    "$SCRIPT_DIR/DesktopSweep/Models/SweepConfig.swift"
    "$SCRIPT_DIR/DesktopSweep/Services/ScriptRunner.swift"
    "$SCRIPT_DIR/DesktopSweep/Services/LaunchdManager.swift"
)

echo "Building $APP_NAME (universal: arm64 + x86_64)..."

rm -rf "$BUILD_DIR"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources" "$BUILD_DIR/tmp"

for arch in arm64 x86_64; do
    echo "  Compiling for $arch..."
    swiftc \
        -target "${arch}-apple-macos13.0" \
        -sdk "$SDK" \
        -framework SwiftUI \
        -framework AppKit \
        -framework Combine \
        -parse-as-library \
        -O \
        -o "$BUILD_DIR/tmp/$EXECUTABLE-$arch" \
        "${SOURCES[@]}"
done

echo "  Creating universal binary..."
lipo -create \
    "$BUILD_DIR/tmp/$EXECUTABLE-arm64" \
    "$BUILD_DIR/tmp/$EXECUTABLE-x86_64" \
    -output "$CONTENTS/MacOS/$EXECUTABLE"

rm -rf "$BUILD_DIR/tmp"

cp "$SCRIPT_DIR/DesktopSweep/Info.plist" "$CONTENTS/Info.plist"
cp "$SCRIPT_DIR/DesktopSweep/AppIcon.icns" "$CONTENTS/Resources/AppIcon.icns"
cp "$SCRIPT_DIR/resources/archive-desktop.sh" "$CONTENTS/Resources/"
cp "$SCRIPT_DIR/resources/config.cfg" "$CONTENTS/Resources/"
chmod +x "$CONTENTS/Resources/archive-desktop.sh"

echo ""
echo "Build complete: $APP_BUNDLE"

# --- Create DMG with drag-to-Applications layout ---

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$CONTENTS/Info.plist")
DMG_NAME="Desktop-Sweep-v${VERSION}"
DMG_STAGING="$BUILD_DIR/dmg-staging"
DMG_TEMP="$BUILD_DIR/temp.dmg"
DMG_FINAL="$BUILD_DIR/$DMG_NAME.dmg"

echo "Creating DMG installer..."

rm -rf "$DMG_STAGING" "$DMG_TEMP" "$DMG_FINAL"
mkdir -p "$DMG_STAGING"
cp -R "$APP_BUNDLE" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_STAGING" \
    -ov -format UDRW "$DMG_TEMP" > /dev/null

MOUNT_OUT=$(hdiutil attach -readwrite -noverify "$DMG_TEMP")
MOUNT_DEV=$(echo "$MOUNT_OUT" | head -1 | awk '{print $1}')

osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$APP_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {400, 150, 900, 500}
        set theViewOptions to icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 100
        set position of item "$APP_NAME.app" of container window to {120, 180}
        set position of item "Applications" of container window to {380, 180}
        close
        open
        update without registering applications
    end tell
end tell
APPLESCRIPT

sleep 2
hdiutil detach "$MOUNT_DEV" -quiet
hdiutil convert "$DMG_TEMP" -format UDZO -o "$DMG_FINAL" > /dev/null
rm -f "$DMG_TEMP"
rm -rf "$DMG_STAGING"

echo ""
echo "DMG ready: $DMG_FINAL"
echo ""
echo "To run:     open \"$APP_BUNDLE\""
echo "To install: Open the DMG and drag Desktop Sweep to Applications"
