#!/usr/bin/env bash
#
# Build a Release Enhancify.app and wrap it in a distributable DMG.
#
# Default signing is ad-hoc ("-"). That needs no Apple Developer Program.
# Recipients clear Gatekeeper once with:
#
#     xattr -cr /Applications/Enhancify.app
#
# Optional: ENHANCIFY_SIGN_IDENTITY for a local cert or Developer ID.
# Optional: NOTARIZE=1 plus Apple notary credentials.
#
set -euo pipefail

cd "$(dirname "$0")/.."

IDENTITY="${ENHANCIFY_SIGN_IDENTITY:--}"
VERSION=$(awk '/MARKETING_VERSION/ {print $2; exit}' project.yml | tr -d '"')
STAGE=$(mktemp -d)
OUT="${ENHANCIFY_DMG_OUT:-build/Enhancify-${VERSION}.dmg}"
trap 'rm -rf "$STAGE"' EXIT

if [[ "$IDENTITY" != "-" ]] \
    && ! security find-identity -v -p codesigning 2>/dev/null | grep -Fq "$IDENTITY"; then
    echo "error: signing identity not found: $IDENTITY" >&2
    exit 1
fi

echo "==> generating project"
XCODEGEN=""
if command -v xcodegen >/dev/null 2>&1; then
    XCODEGEN="xcodegen"
elif [[ -x .tools/xcodegen/bin/xcodegen ]]; then
    XCODEGEN=".tools/xcodegen/bin/xcodegen"
else
    echo "error: xcodegen is required. Install it with: brew install xcodegen" >&2
    exit 1
fi
"$XCODEGEN" generate >/dev/null

echo "==> building Release (identity: $IDENTITY)"
ARCHIVE="$STAGE/Enhancify.xcarchive"
xcodebuild -scheme Enhancify -configuration Release archive \
    -archivePath "$ARCHIVE" -destination 'generic/platform=macOS' \
    >/tmp/enhancify-dmg-build.log 2>&1 \
    || { tail -30 /tmp/enhancify-dmg-build.log; exit 1; }

APP="$ARCHIVE/Products/Applications/Enhancify.app"

echo "==> signing Enhancify.app"
mkdir -p "$STAGE/dmg"
cp -R "$APP" "$STAGE/dmg/Enhancify.app"
codesign -f -s "$IDENTITY" --deep --options runtime \
    --entitlements Resources/Enhancify.entitlements \
    "$STAGE/dmg/Enhancify.app"
codesign --verify --verbose=2 "$STAGE/dmg/Enhancify.app"

if [[ "${NOTARIZE:-}" == "1" && "$IDENTITY" != "-" ]]; then
    echo "==> notarizing Enhancify.app before packaging"
    ./scripts/notarize.sh "$STAGE/dmg/Enhancify.app"
fi

ln -s /Applications "$STAGE/dmg/Applications"
cat > "$STAGE/dmg/How to allow Enhancify.txt" <<'EOF'
Install
1. Drag Enhancify into Applications.
2. Open Terminal and paste this once:

xattr -cr /Applications/Enhancify.app

3. Open Enhancify from Applications.

macOS blocks unsigned downloads. That one line clears the quarantine flag.
You can also Control-click Enhancify.app and choose Open.
EOF

echo "==> building $OUT"
mkdir -p "$(dirname "$OUT")"
rm -f "$OUT"
hdiutil create -volname "Enhancify" -srcfolder "$STAGE/dmg" -ov -format UDZO "$OUT" >/dev/null

if [[ "${NOTARIZE:-}" == "1" && "$IDENTITY" != "-" ]]; then
    echo "==> notarizing DMG"
    ./scripts/notarize.sh "$OUT"
fi

echo "==> done: $OUT ($(du -h "$OUT" | cut -f1))"
if [[ "$IDENTITY" == "-" ]]; then
    echo ""
    echo "==> Recipients: drag Enhancify.app to Applications, then run:"
    echo "    xattr -cr /Applications/Enhancify.app"
fi
