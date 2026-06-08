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

# Sign the same way the release workflow does (release-fork.yml) so local
# builds behave like shipped ones. A plain `--deep --sign -` strips entitlements
# (breaks TCC prompts) and lets Xcode's default sandbox stick on the helper,
# which blocks DisplayServices brightness writes. Sign each piece explicitly.
HELPER="$APP_PATH/Contents/XPCServices/BoringNotchXPCHelper.xpc"
if [[ -d "$HELPER" ]]; then
  codesign --force --sign - \
    --entitlements "$ROOT_DIR/BoringNotchXPCHelper/BoringNotchXPCHelper.entitlements" \
    "$HELPER" >/dev/null
fi
for FW in "$APP_PATH"/Contents/Frameworks/*.framework "$APP_PATH"/Contents/Frameworks/*.dylib; do
  [[ -e "$FW" ]] || continue
  codesign --force --sign - "$FW" >/dev/null
done
codesign --force --sign - \
  --entitlements "$ROOT_DIR/NotchMac/NotchMac.entitlements" \
  "$APP_PATH" >/dev/null

echo "$APP_PATH"

# Launch if --open passed (or no arg)
if [[ "${1:-}" == "--no-open" ]]; then
  exit 0
fi
open "$APP_PATH"
