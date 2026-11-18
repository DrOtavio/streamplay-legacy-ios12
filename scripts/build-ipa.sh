#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="$PWD/dist"
mkdir -p "$OUT"
xcodebuild -project StreamPlayLegacy.xcodeproj -scheme StreamPlayLegacy -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath "$PWD/.build" \
  CODE_SIGNING_ALLOWED=NO build
APP="$PWD/.build/Build/Products/Release-iphoneos/StreamPlayLegacy.app"
test -d "$APP"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/Payload"
cp -R "$APP" "$STAGE/Payload/StreamPlayLegacy.app"
(cd "$STAGE" && /usr/bin/zip -q -r "$OUT/StreamPlayLegacy-iOS12-unsigned.ipa" Payload)
echo "IPA: dist/StreamPlayLegacy-iOS12-unsigned.ipa"
