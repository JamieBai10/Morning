#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ICON_PATH="$ROOT_DIR/Sources/MorningFolder/App/Assets/AppIcon.icns"
PLIST_PATH="$ROOT_DIR/Sources/MorningFolder/App/Info.plist"

test -f "$ICON_PATH"
! grep -q "applicationIconImage" "$ROOT_DIR/Sources/MorningFolder/App/MorningFolderApp.swift"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$PLIST_PATH")" = "AppIcon"

iconset_dir=$(mktemp -d /private/tmp/morning-icon-regression.XXXXXX)/AppIcon.iconset
iconutil -c iconset "$ICON_PATH" -o "$iconset_dir"
test "$(sips -g hasAlpha "$iconset_dir/icon_512x512@2x.png" | awk '/hasAlpha/ { print $2 }')" = "yes"

echo "Packaged app icon contract passed."
