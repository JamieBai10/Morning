#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

for file in "$ROOT_DIR/Sources/MorningFolder/Views/TodayView.swift" "$ROOT_DIR/Sources/MorningFolder/Views/YesterdayView.swift"; do
  width=$(awk '/MorningDateFormatter.displayLabel/ { seen=1 } seen && /frame\(width:/ { gsub(/.*frame\(width: /, ""); gsub(/,.*/, ""); print; exit }' "$file")
  test -n "$width"
  awk -v width="$width" 'BEGIN { exit(width >= 170 ? 0 : 1) }'
done

echo "Date label width regression passed."
