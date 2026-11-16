#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Morning"
BUNDLE_ID="com.jamie.morning"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
SOURCE_INFO_PLIST="$ROOT_DIR/Sources/MorningFolder/App/Info.plist"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_ICON="$ROOT_DIR/Sources/MorningFolder/App/Assets/AppIcon.icns"
ARCHIVE_PATH="$DIST_DIR/${APP_NAME}-macOS.zip"
INSTALL_GUIDE="$ROOT_DIR/Distribution/安装前请先阅读.txt"
FEISHU_GUIDE="$ROOT_DIR/Distribution/飞书日历连接指南.txt"
RELEASE_NOTES="$ROOT_DIR/Distribution/发布说明.txt"

cd "$ROOT_DIR"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

swift build
BUILD_DIR="$(swift build --show-bin-path)"
BUILD_BINARY="$BUILD_DIR/$APP_NAME"
/usr/bin/codesign --force --sign - --identifier "$BUNDLE_ID" "$BUILD_BINARY" >/dev/null

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

find "$BUILD_DIR" -maxdepth 1 -name "${APP_NAME}_MorningFolder.bundle" -type d -exec cp -R {} "$APP_RESOURCES/" \;

cp "$SOURCE_INFO_PLIST" "$INFO_PLIST"
cp "$APP_ICON" "$APP_RESOURCES/AppIcon.icns"
/usr/bin/codesign --force --sign - --identifier "$BUNDLE_ID" "$APP_BUNDLE" >/dev/null
/usr/bin/codesign --verify --deep --strict "$APP_BUNDLE"

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  --archive|archive)
    test -f "$INSTALL_GUIDE"
    test -f "$FEISHU_GUIDE"
    test -f "$RELEASE_NOTES"
    STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/morning-archive.XXXXXX")"
    trap 'rm -rf "$STAGING_DIR"' EXIT
    /usr/bin/ditto "$APP_BUNDLE" "$STAGING_DIR/$APP_NAME.app"
    cp "$INSTALL_GUIDE" "$STAGING_DIR/Read-Me-First.txt"
    cp "$FEISHU_GUIDE" "$STAGING_DIR/Feishu-Calendar-Guide.txt"
    cp "$RELEASE_NOTES" "$STAGING_DIR/Release-Notes.txt"
    /usr/bin/ditto -c -k --sequesterRsrc "$STAGING_DIR" "$ARCHIVE_PATH"
    echo "$ARCHIVE_PATH"
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify|--archive]" >&2
    exit 2
    ;;
esac
