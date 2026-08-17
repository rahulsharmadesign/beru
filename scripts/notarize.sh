#!/usr/bin/env bash
#
# Notarize and staple a Beru.app bundle or .dmg with Apple's notary service.
#
# Required environment variables:
#   APPLE_ID                  Apple ID email
#   APPLE_APP_SPECIFIC_PASSWORD  App-specific password from appleid.apple.com
#   APPLE_TEAM_ID             10-character Team ID
#
# Optional:
#   NOTARY_PROFILE            notarytool keychain profile name (avoids passing creds each time)
#
set -euo pipefail

TARGET="${1:?usage: notarize.sh <Beru.app|Beru.dmg>}"
cd "$(dirname "$0")/.."

if [[ ! -e "$TARGET" ]]; then
    echo "error: not found: $TARGET" >&2
    exit 1
fi

SUBMIT_ARGS=()
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    SUBMIT_ARGS+=(--keychain-profile "$NOTARY_PROFILE")
else
    for var in APPLE_ID APPLE_APP_SPECIFIC_PASSWORD APPLE_TEAM_ID; do
        if [[ -z "${!var:-}" ]]; then
            echo "error: $var is required (or set NOTARY_PROFILE)" >&2
            exit 1
        fi
    done
    SUBMIT_ARGS+=(--apple-id "$APPLE_ID" --password "$APPLE_APP_SPECIFIC_PASSWORD" --team-id "$APPLE_TEAM_ID")
fi

echo "==> submitting $TARGET for notarization"
xcrun notarytool submit "$TARGET" "${SUBMIT_ARGS[@]}" --wait

echo "==> stapling ticket"
if [[ "$TARGET" == *.dmg ]]; then
    xcrun stapler staple "$TARGET"
else
    xcrun stapler staple "$TARGET"
fi

echo "==> verifying Gatekeeper acceptance"
spctl -a -vv -t install "$TARGET" 2>&1 || spctl -a -vv "$TARGET" 2>&1

echo "==> notarization complete: $TARGET"
