#!/usr/bin/env bash
set -euo pipefail

if ! command -v keytool >/dev/null 2>&1; then
  echo "keytool not found. Install a JDK (e.g., OpenJDK 17) and retry." >&2
  exit 1
fi

KEYSTORE_PATH=${1:-"keystore/engenho-digital.jks"}
ALIAS=${2:-"engenho_digital"}
VALIDITY_DAYS=${3:-"10000"}

mkdir -p "$(dirname "$KEYSTORE_PATH")"

keytool -genkeypair \
  -storetype JKS \
  -keystore "$KEYSTORE_PATH" \
  -alias "$ALIAS" \
  -keyalg RSA \
  -keysize 2048 \
  -validity "$VALIDITY_DAYS"

echo "Keystore criado em: $KEYSTORE_PATH"
