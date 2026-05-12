#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="NotchMac"
SCHEME="NotchMac"
PROJECT="$ROOT_DIR/${SCHEME}.xcodeproj"
DERIVED="$ROOT_DIR/build"
APP_PATH="$DERIVED/Build/Products/Debug/${APP_NAME}.app"

cd "$ROOT_DIR"

# Kill running instance (silent if not running)
pkill -x "$APP_NAME" 2>/dev/null || true

# Build (quiet — only errors)
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  build -quiet

codesign --force --deep --sign - "$APP_PATH" >/dev/null

echo "$APP_PATH"

# Launch if --open passed (or no arg)
if [[ "${1:-}" == "--no-open" ]]; then
  exit 0
fi
open "$APP_PATH"
