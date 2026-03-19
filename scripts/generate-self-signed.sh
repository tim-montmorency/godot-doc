#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERT_DIR="$SCRIPT_DIR/certs"
mkdir -p "$CERT_DIR"

KEY_PATH="$CERT_DIR/key.pem"
CERT_PATH="$CERT_DIR/cert.pem"
FULLCHAIN_PATH="$CERT_DIR/fullchain.pem"

if ! command -v openssl >/dev/null 2>&1; then
  echo "Error: openssl is required but not found. Install it via Homebrew: brew install openssl" >&2
  exit 2
fi

echo "Collecting hostnames/IPs for SAN (localhost, 127.0.0.1, and local LAN IPv4 addresses)"
SAN_NAMES=("DNS:localhost" "IP:127.0.0.1")

# Collect non-internal IPv4 addresses
if command -v ip >/dev/null 2>&1; then
  # linux ip command
  while read -r addr; do
    SAN_NAMES+=("IP:${addr}")
  done < <(ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1)
elif command -v ifconfig >/dev/null 2>&1; then
  # macOS / BSD ifconfig
  while read -r addr; do
    SAN_NAMES+=("IP:${addr}")
  done < <(ifconfig | awk '/inet / && $2 != "127.0.0.1" {print $2}')
fi

echo "SAN entries:" ${SAN_NAMES[*]}

TMP_CNF=$(mktemp /tmp/openssl.cnf.XXXXXX)
cat > "$TMP_CNF" <<EOF
[ req ]
default_bits       = 2048
distinguished_name = req_distinguished_name
req_extensions     = req_ext
prompt             = no

[ req_distinguished_name ]
CN = localhost

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
EOF

idx=1
for name in "${SAN_NAMES[@]}"; do
  echo "$name" | awk -F: '{print $1":"$2}' >/dev/null
  # convert to openssl-style alt_names lines
  if [[ "$name" == IP:* ]]; then
    echo "IP.$idx = ${name#IP:}" >> "$TMP_CNF"
  else
    echo "DNS.$idx = ${name#DNS:}" >> "$TMP_CNF"
  fi
  idx=$((idx+1))
done

echo "Generating a self-signed certificate with SAN..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "$KEY_PATH" -out "$CERT_PATH" -config "$TMP_CNF" -extensions req_ext

# Combine cert + key for convenience
cat "$CERT_PATH" "$KEY_PATH" > "$FULLCHAIN_PATH"

rm -f "$TMP_CNF"

echo "Generated: $KEY_PATH, $CERT_PATH"

if [[ "$(uname)" == "Darwin" ]]; then
  echo "On macOS: you can add the certificate to the System keychain to avoid browser warnings."
  read -r -p "Add certificate to System keychain (requires sudo)? [y/N]: " yn
  if [[ $yn == [Yy] ]]; then
    echo "Adding to System keychain..."
    sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$CERT_PATH"
    echo "Certificate added to System keychain (system-wide trust)."
  else
    echo "You chose not to add the certificate to the System keychain. You can manually add $CERT_PATH to your keychain."
  fi
fi

echo "Done. Certificates are in: $CERT_DIR"
echo "To run the server:"
echo "  node scripts/serve-https.js"
echo "or use VS Code Run -> 'Launch HTTPS Static Server' which will run the generate step first."
