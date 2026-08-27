#!/usr/bin/env bash
#
# Build Beru, sign it with the stable local certificate, install to
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
#     designated => identifier "com.rahul.beru" and certificate root = H"7dc2bd8c…"
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
#     security find-identity -v | grep "Beru Local Signing"
#
set -euo pipefail

IDENTITY="${BERU_SIGN_IDENTITY:-Beru Local Signing}"
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
xcodebuild -scheme Beru -configuration Debug build -destination 'platform=macOS' \
    >/tmp/beru-build.log 2>&1 || { tail -30 /tmp/beru-build.log; exit 1; }

BUILT=$(ls -td "$HOME"/Library/Developer/Xcode/DerivedData/Beru-*/Build/Products/Debug/Beru.app | head -1)

echo "==> installing to /Applications"
killall Beru 2>/dev/null || true
pkill -f "Beru.app/Contents/MacOS/Beru" 2>/dev/null || true
# Wait until the old process is gone so the new binary owns the hotkey.
for _ in $(seq 1 40); do
    if ! pgrep -x Beru >/dev/null 2>&1; then
        break
    fi
    sleep 0.1
done
if pgrep -x Beru >/dev/null 2>&1; then
    echo "error: Beru is still running; quit it from the menu bar and retry." >&2
    exit 1
fi
rm -rf /Applications/Beru.app
cp -R "$BUILT" /Applications/Beru.app

echo "==> signing with '$IDENTITY' (hardened runtime)"
# --options runtime preserves the hardened runtime flag from the build.
# --entitlements includes audio-input (required under Hardened Runtime).
# --deep signs nested Debug dylibs so they share this identity. Without it,
# dyld refuses to load Beru.debug.dylib (different Team IDs).
codesign -f -s "$IDENTITY" --deep --options runtime \
    --entitlements Resources/Beru.entitlements \
    /Applications/Beru.app
codesign -d -r- /Applications/Beru.app 2>&1 | grep designated
codesign -dvvv /Applications/Beru.app 2>&1 | grep -E "(Runtime|Flags)"

open /Applications/Beru.app
# Confirm the new process is up (hotkey registration happens in start()).
for _ in $(seq 1 30); do
    if pgrep -x Beru >/dev/null 2>&1; then
        echo "==> launched"
        exit 0
    fi
    sleep 0.1
done
echo "error: Beru did not start. Open /Applications/Beru.app from Finder." >&2
exit 1
