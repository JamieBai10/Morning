#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc "$ROOT_DIR/Sources/MorningFolder/Support/WindowDragInteraction.swift" "$ROOT_DIR/Tests/WindowDragRegression/main.swift" -o "$TEST_DIR/test"
"$TEST_DIR/test"
