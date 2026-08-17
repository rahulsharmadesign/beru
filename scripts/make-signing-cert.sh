#!/usr/bin/env bash
#
# Create the local code-signing certificate Beru is signed with, and import
# it into the login keychain. Run once; scripts/install.sh uses it thereafter.
#
# Why a certificate at all: an ad-hoc signature's designated requirement is the
# binary's cdhash, so TCC treats every rebuild as a different app and the
# Accessibility grant has to be re-granted every time. A certificate gives a
# requirement of bundle-id + certificate, which is stable across rebuilds.
#
# Why self-signed: a paid Developer ID certificate would also work, and would
# additionally allow notarisation for sharing the app. This is the free local
# equivalent for development builds on this machine.
#
# This certificate signs nothing but local builds. It is not trusted as a root, it
# cannot vouch for anything to anyone else, and removing it is a one-liner:
#     security delete-certificate -c "Beru Local Signing"
#
set -euo pipefail

NAME="Beru Local Signing"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-certificate -c "$NAME" >/dev/null 2>&1; then
    echo "'$NAME' already exists in the keychain — nothing to do."
    exit 0
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/cert.cnf" <<EOF
[ req ]
distinguished_name = dn
x509_extensions = v3
prompt = no
[ dn ]
CN = $NAME
O = Beru Local
[ v3 ]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
subjectKeyIdentifier = hash
EOF

openssl req -x509 -newkey rsa:2048 -keyout "$WORK/key.pem" -out "$WORK/cert.pem" \
    -days 3650 -nodes -config "$WORK/cert.cnf" >/dev/null 2>&1

# Legacy PBE and a non-empty transit password: OpenSSL 3's defaults produce a MAC
# that macOS cannot read ("MAC verification failed during PKCS12 import"). The
# password protects nothing beyond this temp file, which is deleted on exit.
openssl pkcs12 -export -inkey "$WORK/key.pem" -in "$WORK/cert.pem" -out "$WORK/bundle.p12" \
    -passout pass:transit -name "$NAME" \
    -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1 >/dev/null 2>&1

# -T /usr/bin/codesign pre-authorises codesign to use the private key, so signing
# never raises a keychain prompt.
security import "$WORK/bundle.p12" -k "$KEYCHAIN" -P transit \
    -T /usr/bin/codesign -T /usr/bin/security

echo "created '$NAME'."
echo
echo "IMPORTANT, one time only: macOS still holds Accessibility entries for the old"
echo "ad-hoc builds. In System Settings > Privacy & Security > Accessibility, remove"
echo "every Beru row with '-', then add the freshly signed app with '+'."
echo "From then on the grant survives rebuilds."
