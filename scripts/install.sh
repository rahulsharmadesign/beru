#!/usr/bin/env bash
#
# Build Enhancify, sign it with the stable local certificate, install to
# /Applications, and launch it.
#
# The signing step is the whole point of this script. An ad-hoc signature's
# designated requirement is the binary's cdhash:
#
#     designated => cdhash H"2146e26d…"
#
# TCC keys the Accessibility grant to that, so every rebuild looks like a
# brand-new app to macOS and the grant silently stops applying — which is why the
# permission had to be re-g ranted after every single build. Signing with a
# certificate makes the requirement bundle-id + certificate instead:
#
#     designated => identifier "com.rahul.enhancify" and certificate root = H"7dc2bd8c…"
#
# That is identical across rebuilds, so the grant persists.
#
# Signing happens here rather than in the Xcode project because Xcode runs its own
# code-signing step after every build phase, so a post-build script inside the
# target would just be overwritten.
#
# Hardened Runtime:
# The app is built with ENABLE_HARDENED_RUNTIME: YES in project.yml. This script
# re-signs with --options runtime to preserve the hardened runtime flag, and
# includes the entitlements file for any runtime exceptions (currently none needed).
#
# One-time setup, if the certificate is ever missing (see scripts/make-signing-cert.sh):
#     security find-identity -v | grep "Enhancify Local Signing"
#
set -euo pipefail

IDENTITY="${ENHANCIFY_SIGN_IDENTITY:-Enhancify Local Signing}"
cd "$(dirname "$0")/.."

if ! security find-certificate -c "$IDENTITY" >/dev/null 2>&1; then
    echo "error: signing certificate '$IDENTITY' not found in the keychain." >&2
    echo "       run scripts/make-signing-cert.sh first, or the Accessibility" >&2
    echo "       grant will break on every rebuild." >&2
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

echo "==> building"
xcodebuild -scheme Enhancify -configuration Debug build -destination 'platform=macOS' \
    >/tmp/enhancify-build.log 2>&1 || { tail -30 /tmp/enhancify-build.log; exit 1; }

# Ask this project where it wrote the app. Globbing DerivedData/Enhancify-* picks
# whichever folder was touched last — a leftover checkout can be newer and
# install an old marketing version (1.1.0 instead of this tree).
BUILT_PRODUCTS_DIR=$(xcodebuild -scheme Enhancify -configuration Debug \
    -destination 'platform=macOS' -showBuildSettings 2>/dev/null \
    | sed -n 's/^[[:space:]]*BUILT_PRODUCTS_DIR = //p' | head -1)
BUILT="${BUILT_PRODUCTS_DIR}/Enhancify.app"
if [[ ! -d "$BUILT" ]]; then
    echo "error: built app not found at $BUILT" >&2
    exit 1
fi

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$BUILT/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$BUILT/Contents/Info.plist")
echo "==> installing ${VERSION} (${BUILD}) to /Applications"
killall Enhancify 2>/dev/null || true
pkill -f "Enhancify.app/Contents/MacOS/Enhancify" 2>/dev/null || true
# Wait until the old process is gone so the new binary owns the hotkey.
for _ in $(seq 1 40); do
    if ! pgrep -x Enhancify >/dev/null 2>&1; then
        break
    fi
    sleep 0.1
done
if pgrep -x Enhancify >/dev/null 2>&1; then
    echo "warning: Enhancify ignored SIGTERM; sending SIGKILL" >&2
    pkill -9 -x Enhancify 2>/dev/null || true
    sleep 1
fi
if pgrep -x Enhancify >/dev/null 2>&1; then
    echo "error: Enhancify is still running; quit it from the menu bar and retry." >&2
    exit 1
fi
rm -rf /Applications/Enhancify.app
cp -R "$BUILT" /Applications/Enhancify.app

echo "==> signing with '$IDENTITY' (hardened runtime)"
# --options runtime preserves the hardened runtime flag from the build.
# --entitlements includes audio-input (required under Hardened Runtime).
# --deep signs nested Debug dylibs so they share this identity. Without it,
# dyld refuses to load Enhancify.debug.dylib (different Team IDs).
codesign -f -s "$IDENTITY" --deep --options runtime \
    --entitlements Resources/Enhancify.entitlements \
    /Applications/Enhancify.app
codesign -d -r- /Applications/Enhancify.app 2>&1 | grep designated
codesign -dvvv /Applications/Enhancify.app 2>&1 | grep -E "(Runtime|Flags)"

open /Applications/Enhancify.app
# Confirm the new process is up (hotkey registration happens in start()).
for _ in $(seq 1 30); do
    if pgrep -x Enhancify >/dev/null 2>&1; then
        echo "==> launched"
        exit 0
    fi
    sleep 0.1
done
echo "error: Enhancify did not start. Open /Applications/Enhancify.app from Finder." >&2
exit 1
