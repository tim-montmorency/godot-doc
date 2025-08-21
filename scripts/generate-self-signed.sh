#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERT_DIR="$SCRIPT_DIR/certs"
mkdir -p "$CERT_DIR"

KEY_PATH="$CERT_DIR/key.pem"
CERT_PATH="$CERT_DIR/cert.pem"
FULLCHAIN_PATH="$CERT_DIR/fullchain.pem"

if command -v openssl >/dev/null 2>&1; then
  echo "Generating a self-signed certificate for localhost..."
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$KEY_PATH" -out "$CERT_PATH" \
    -subj "/CN=localhost"
  # Combine cert + key for convenience
  cat "$CERT_PATH" "$KEY_PATH" > "$FULLCHAIN_PATH"
  echo "Generated: $KEY_PATH, $CERT_PATH"
else
  echo "Error: openssl is required but not found. Install it via Homebrew: brew install openssl" >&2
  exit 2
fi

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
