#!/bin/sh
set -e

CERT_DIR=/certs

mkdir -p "$CERT_DIR"

# Generate CA key and cert
openssl genrsa -out "$CERT_DIR/ca.key" 2048
openssl req -x509 -new -nodes -key "$CERT_DIR/ca.key" -sha256 -days 365 \
  -out "$CERT_DIR/ca.pem" -subj "/CN=Test Root CA"

# Generate server key and CSR
openssl genrsa -out "$CERT_DIR/server.key" 2048
openssl req -new -key "$CERT_DIR/server.key" \
  -out "$CERT_DIR/server.csr" -subj "/CN=lb"

# Create extensions file for SAN
cat > "$CERT_DIR/server.ext" <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = DNS:lb,DNS:localhost,IP:127.0.0.1
EOF

# Sign server cert with CA
openssl x509 -req -in "$CERT_DIR/server.csr" \
  -CA "$CERT_DIR/ca.pem" -CAkey "$CERT_DIR/ca.key" -CAcreateserial \
  -out "$CERT_DIR/server.pem" -days 365 -sha256 \
  -extfile "$CERT_DIR/server.ext"

echo "TLS certificates generated in $CERT_DIR"
ls -la "$CERT_DIR"
