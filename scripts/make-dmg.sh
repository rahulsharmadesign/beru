#!/usr/bin/env bash
#
# Build a Release Beru.app and wrap it in a distributable DMG.
#
# Default signing is ad-hoc ("-"). That needs no Apple Developer Program.
# Recipients clear Gatekeeper once with:
#
#     xattr -cr /Applications/Beru.app
#
# Optional: BERU_SIGN_IDENTITY for a local cert or Developer ID.
# Optional: NOTARIZE=1 plus Apple notary credentials.
#
set -euo pipefail

cd "$(dirname "$0")/.."

IDENTITY="${BERU_SIGN_IDENTITY:--}"
VERSION=$(awk '/MARKETING_VERSION/ {print $2; exit}' project.yml | tr -d '"')
STAGE=$(mktemp -d)
OUT="${BERU_DMG_OUT:-build/Beru-${VERSION}.dmg}"
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
ARCHIVE="$STAGE/Beru.xcarchive"
xcodebuild -scheme Beru -configuration Release archive \
    -archivePath "$ARCHIVE" -destination 'generic/platform=macOS' \
    >/tmp/beru-dmg-build.log 2>&1 \
    || { tail -30 /tmp/beru-dmg-build.log; exit 1; }

APP="$ARCHIVE/Products/Applications/Beru.app"

echo "==> signing Beru.app"
mkdir -p "$STAGE/dmg"
cp -R "$APP" "$STAGE/dmg/Beru.app"
codesign -f -s "$IDENTITY" --deep --options runtime \
    --entitlements Resources/Beru.entitlements \
    "$STAGE/dmg/Beru.app"
codesign --verify --verbose=2 "$STAGE/dmg/Beru.app"

if [[ "${NOTARIZE:-}" == "1" && "$IDENTITY" != "-" ]]; then
    echo "==> notarizing Beru.app before packaging"
    ./scripts/notarize.sh "$STAGE/dmg/Beru.app"
fi

ln -s /Applications "$STAGE/dmg/Applications"
cat > "$STAGE/dmg/How to allow Beru.txt" <<'EOF'
Install
1. Drag Beru into Applications.
2. Open Terminal and paste this once:

xattr -cr /Applications/Beru.app

3. Open Beru from Applications.

macOS blocks unsigned downloads. That one line clears the quarantine flag.
You can also Control-click Beru and choose Open.
EOF

echo "==> building $OUT"
mkdir -p "$(dirname "$OUT")"
rm -f "$OUT"
hdiutil create -volname "Beru" -srcfolder "$STAGE/dmg" -ov -format UDZO "$OUT" >/dev/null

if [[ "${NOTARIZE:-}" == "1" && "$IDENTITY" != "-" ]]; then
    echo "==> notarizing DMG"
    ./scripts/notarize.sh "$OUT"
fi

echo "==> done: $OUT ($(du -h "$OUT" | cut -f1))"
if [[ "$IDENTITY" == "-" ]]; then
    echo ""
    echo "==> Recipients: drag Beru to Applications, then run:"
    echo "    xattr -cr /Applications/Beru.app"
fi
