#!/usr/bin/env bash
#
# Package the SplitForgeApp SwiftPM executable into an installable SplitForge.app and install it.
# Menu-bar agent (no dock icon), ad-hoc signed. See plan/M6-packaging.md.
#
set -euo pipefail

APP_NAME="SplitForge"
BUNDLE_ID="com.splitforge.app"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MACAPP="$ROOT/macapp"
STAGE="$MACAPP/.build/app"
APP="$STAGE/$APP_NAME.app"

echo "==> Release build…"
( cd "$MACAPP" && swift build -c release )

BIN="$MACAPP/.build/release/SplitForgeApp"
# Derive the resource bundle name from the build output rather than hardcoding it.
RES_BUNDLE="$(ls -d "$MACAPP"/.build/release/*_SplitForgeCore.bundle 2>/dev/null | head -1 || true)"

[ -x "$BIN" ] || { echo "ERROR: release binary not found at $BIN"; exit 1; }
[ -n "$RES_BUNDLE" ] && [ -d "$RES_BUNDLE" ] || { echo "ERROR: SplitForgeCore resource bundle not found in .build/release"; exit 1; }
RES_NAME="$(basename "$RES_BUNDLE")"

echo "==> Assembling $APP_NAME.app…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
cp -R "$RES_BUNDLE" "$APP/Contents/Resources/"
[ -f "$ROOT/tools/AppIcon.icns" ] && cp "$ROOT/tools/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleShortVersionString</key><string>0.1</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>LSUIElement</key><true/>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
</dict>
</plist>
PLIST

# Pre-check: the resource bundle (and totem.json inside it) must be in Contents/Resources.
[ -d "$APP/Contents/Resources/$RES_NAME" ] || { echo "ERROR: resource bundle missing in Contents/Resources"; exit 1; }
if ! find "$APP/Contents/Resources/$RES_NAME" -name 'totem.json' | grep -q .; then
    echo "ERROR: totem.json not found inside the bundled resources"; exit 1
fi

echo "==> Code signing…"
# The SplitForgeCore resource bundle is data only (totem.json, no Mach-O), so it is NOT a
# separately-signable code bundle — it's sealed as a resource when we ad-hoc sign the app.
codesign --force -s - "$APP"
# Keep verify as its own statement: in an `&&` list it would be exempt from `set -e`, silently
# swallowing a bad-signature failure and installing anyway.
codesign --verify --strict "$APP"
echo "  signature verified"

# Pick an install location: /Applications if writable, else ~/Applications.
if [ -w /Applications ]; then DEST="/Applications"; else DEST="$HOME/Applications"; mkdir -p "$DEST"; fi

echo "==> Quitting any running instance…"
osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
pkill -f "$APP_NAME.app/Contents/MacOS/$APP_NAME" 2>/dev/null || true
pkill -f "release/SplitForgeApp" 2>/dev/null || true
pkill -f "debug/SplitForgeApp" 2>/dev/null || true
sleep 1

echo "==> Installing to $DEST/$APP_NAME.app…"
rm -rf "$DEST/$APP_NAME.app"
cp -R "$APP" "$DEST/"

# Refresh Finder/Spotlight icon caches — they don't update on a same-path reinstall. lsregister
# isn't on PATH, so use its full path.
touch "$DEST/$APP_NAME.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Support/lsregister"
[ -x "$LSREGISTER" ] && "$LSREGISTER" -f "$DEST/$APP_NAME.app" >/dev/null 2>&1 || true

echo ""
echo "Installed: $DEST/$APP_NAME.app"
echo "Launch \"$APP_NAME\" from Spotlight/Launchpad. On first run, grant Input Monitoring"
echo "(System Settings -> Privacy & Security -> Input Monitoring)."
