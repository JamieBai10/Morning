#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc "$ROOT_DIR/Sources/MorningNarration/YesterdayExpression.swift" "$ROOT_DIR/Tests/YesterdayExpressionRegression/main.swift" -o "$TEST_DIR/test"
"$TEST_DIR/test"
