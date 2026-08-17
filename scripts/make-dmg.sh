#!/usr/bin/env bash
#
# Build a Release Beru.app and wrap it in a distributable DMG.
#
# Signing identity (first match wins):
#   1. BERU_SIGN_IDENTITY env var
#   2. Developer ID Application identity in the keychain (release / CI)
#   3. "Beru Local Signing" local dev certificate
#
# Notarization (optional, for public distribution):
#   NOTARIZE=1 plus either NOTARY_PROFILE or APPLE_ID + APPLE_APP_SPECIFIC_PASSWORD + APPLE_TEAM_ID
#
# Local dev builds use a self-signed certificate. Other Macs will block Gatekeeper
# until the user right-clicks > Open. Public releases need Developer ID + notarization.
#
set -euo pipefail

cd "$(dirname "$0")/.."

pick_identity() {
    if [[ -n "${BERU_SIGN_IDENTITY:-}" ]]; then
        echo "$BERU_SIGN_IDENTITY"
        return
    fi
    local dev_id
    dev_id=$(security find-identity -v -p codesigning 2>/dev/null \
        | awk -F'"' '/Developer ID Application/ {print $2; exit}')
    if [[ -n "$dev_id" ]]; then
        echo "$dev_id"
        return
    fi
    echo "Beru Local Signing"
}

IDENTITY="$(pick_identity)"
VERSION=$(awk '/MARKETING_VERSION/ {print $2; exit}' project.yml | tr -d '"')
STAGE=$(mktemp -d)
OUT="${BERU_DMG_OUT:-build/Beru-${VERSION}.dmg}"
trap 'rm -rf "$STAGE"' EXIT

if [[ "$IDENTITY" != "-" ]] \
    && ! security find-identity -v -p codesigning 2>/dev/null | grep -Fq "$IDENTITY"; then
    if [[ "$IDENTITY" == "Beru Local Signing" ]]; then
        echo "error: signing certificate '$IDENTITY' not found." >&2
        echo "       run scripts/make-signing-cert.sh for local builds, or import a" >&2
        echo "       Developer ID Application certificate for release builds." >&2
        exit 1
    fi
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
codesign --verify --strict "$STAGE/dmg/Beru.app"

if [[ "${NOTARIZE:-}" == "1" && "$IDENTITY" != "-" ]]; then
    echo "==> notarizing Beru.app before packaging"
    ./scripts/notarize.sh "$STAGE/dmg/Beru.app"
fi

ln -s /Applications "$STAGE/dmg/Applications"

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
    echo "==> Ad-hoc build — not suitable for public download. Add Apple Developer"
    echo "    ID secrets to GitHub Actions before publishing a release."
elif [[ "$IDENTITY" == "Beru Local Signing" ]]; then
    echo ""
    echo "==> Local certificate build — recipients must right-click > Open once,"
    echo "    or run: xattr -dr com.apple.quarantine /Applications/Beru.app"
    echo "    For public download, rebuild with Developer ID + NOTARIZE=1."
fi
