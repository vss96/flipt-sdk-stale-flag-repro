#!/bin/sh
set -e

KEY_DIR="/keys"

if [ -f "$KEY_DIR/private.pem" ] && [ -f "$KEY_DIR/public.pem" ]; then
  echo "RSA keys already exist, skipping generation."
  exit 0
fi

echo "Generating RSA 2048-bit key pair..."
openssl genpkey -algorithm RSA -out "$KEY_DIR/private.pem" -pkeyopt rsa_keygen_bits:2048
openssl rsa -pubout -in "$KEY_DIR/private.pem" -out "$KEY_DIR/public.pem"
chmod 644 "$KEY_DIR/private.pem" "$KEY_DIR/public.pem"
echo "Keys generated in $KEY_DIR"
