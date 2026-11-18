#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc -parse-as-library -module-cache-path "${TMPDIR:-/tmp}/morning-scale-module-cache" \
  "$ROOT_DIR/Sources/MorningFolder/Support/MorningPreferences.swift" \
  "$ROOT_DIR/Sources/MorningFolder/Support/DesignTokens.swift" \
  "$ROOT_DIR/Tests/WidgetScaleRegression/main.swift" -o "$TEST_DIR/test"
"$TEST_DIR/test"
