#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_DIR="$ROOT_DIR/Sources/MorningFolder"

grep -q 'lucky-random-v1' "$ROOT_DIR/Sources/MorningFolder/Stores/LuckyColorProvider.swift"
grep -Fq 'func loadDailyColors() async throws -> [LuckyColor]' "$ROOT_DIR/Sources/MorningFolder/Stores/LuckyColorProvider.swift"
grep -Fq 'func cachedColorsForToday() -> [LuckyColor]?' "$ROOT_DIR/Sources/MorningFolder/Stores/LuckyColorProvider.swift"

! grep -R 'LuckyColorProfile\|birthday\|生日\|zodiacSign\|ZodiacSign\|星座\|属相\|yiqibazi\|todays-lucky-colour' "$SOURCE_DIR" --include='*.swift' >/dev/null

echo "Lucky color random-mode contract passed."
