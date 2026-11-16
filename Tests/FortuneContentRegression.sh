#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LIBRARY="$ROOT_DIR/Sources/MorningFolder/Resources/fortunes.json"

test "$(grep -c '"id"' "$LIBRARY")" -eq 366
test "$(grep -c '"english"' "$LIBRARY")" -eq 366
test "$(grep -c '"chinese"' "$LIBRARY")" -eq 0

if awk -F'"' '/"english"/ { print $4 }' "$LIBRARY" | sort | uniq -d | grep -q .; then
  echo "Duplicate English quote found." >&2
  exit 1
fi
if awk -F'"' '/"chinese"/ { print $4 }' "$LIBRARY" | sort | uniq -d | grep -q .; then
  echo "Duplicate Chinese quote found." >&2
  exit 1
fi

echo "Fortune content uniqueness contract passed."
