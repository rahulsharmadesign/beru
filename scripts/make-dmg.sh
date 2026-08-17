#!/usr/bin/env bash
#
# Build a Release Beru.app and wrap it in a distributable DMG.
#
# IMPORTANT — Gatekeeper on the receiving Mac:
#
# This signs with the same self-signed "Beru Local Signing" certificate
# that scripts/install.sh uses. That certificate exists only in THIS machine's
# keychain, so to any other Mac the app is unsigned by an unknown developer.
# macOS will refuse to open it on a double-click. The receiving user has to
# right-click the app once and choose Open, or run:
#
#     xattr -dr com.apple.quarantine /Applications/Beru.app
#
# Distributing without that friction needs a paid Apple Developer ID plus
# notarisation. Do not present an unsigned or locally signed DMG as the
# recommended install path for public users.
#
# Hardened Runtime:
# The app is built with ENABLE_HARDENED_RUNTIME: YES. This script re-signs
# with --options runtime and --entitlements to preserve hardened runtime for
# notarization readiness. When using a Developer ID, Apple's notary service
# requires hardened runtime to be enabled.
#
set -euo pipefail

IDENTITY="${BERU_SIGN_IDENTITY:-Beru Local Signing}"
cd "$(dirname "$0")/.."

VERSION=$(awk '/MARKETING_VERSION/ {print $2; exit}' project.yml | tr -d '"')
STAGE=$(mktemp -d)
OUT="build/Beru-${VERSION}.dmg"
trap 'rm -rf "$STAGE"' EXIT

echo "==> generating project"
xcodegen generate >/dev/null

# `archive`, not `build`. A Release *scheme* build also compiles the test
# target, and Release turns testability off, so every `@testable import
# Beru` fails to resolve. Restricting to `-target Beru` avoids the
# tests but then SPM dependencies stop resolving, because package resolution
# comes from the scheme. Archiving builds the app and its packages and skips
# the tests, which is exactly what a distributable build wants.
echo "==> building Release"
ARCHIVE="$STAGE/Beru.xcarchive"
xcodebuild -scheme Beru -configuration Release archive \
    -archivePath "$ARCHIVE" -destination 'generic/platform=macOS' \
    >/tmp/beru-dmg-build.log 2>&1 \
    || { tail -30 /tmp/beru-dmg-build.log; exit 1; }

APP="$ARCHIVE/Products/Applications/Beru.app"

echo "==> signing with '$IDENTITY' (hardened runtime)"
mkdir -p "$STAGE/dmg"
cp -R "$APP" "$STAGE/dmg/Beru.app"
# --options runtime preserves hardened runtime flag for notarization.
# --deep signs all nested code (frameworks, helpers).
# --entitlements includes runtime exceptions.
codesign -f -s "$IDENTITY" --deep --options runtime \
    --entitlements Resources/Beru.entitlements \
    "$STAGE/dmg/Beru.app"
codesign --verify --strict "$STAGE/dmg/Beru.app"
echo "==> hardened runtime status:"
codesign -dvvv "$STAGE/dmg/Beru.app" 2>&1 | grep -E "(Runtime|Flags)"

# Drag-to-install layout.
ln -s /Applications "$STAGE/dmg/Applications"

echo "==> building $OUT"
mkdir -p build
rm -f "$OUT"
hdiutil create -volname "Beru" -srcfolder "$STAGE/dmg" -ov -format UDZO "$OUT" >/dev/null

echo "==> done: $OUT ($(du -h "$OUT" | cut -f1))"
echo ""
echo "==> Distribution notes:"
echo "    - This DMG is signed with a local certificate."
echo "    - Recipients must right-click > Open or run:"
echo "      xattr -dr com.apple.quarantine /Applications/Beru.app"
echo "    - For frictionless install, use Apple Developer ID + notarization."
