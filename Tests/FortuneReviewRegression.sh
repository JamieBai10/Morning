#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REVIEW_PAGE="$ROOT_DIR/Docs/fortune-review.html"

test -f "$REVIEW_PAGE"
grep -q 'const quotes =' "$REVIEW_PAGE"
grep -q 'fortune-001' "$REVIEW_PAGE"
grep -q '修改输入' "$REVIEW_PAGE"
grep -q 'morning-fortune-review-v3-english' "$REVIEW_PAGE"
! grep -q 'English / 中文\|q.chinese\|中文 quote' "$REVIEW_PAGE"

echo "Fortune review page contract passed."
