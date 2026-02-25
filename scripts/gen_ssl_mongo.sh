#!/bin/bash
set -euo pipefail

# Generate TLS certificates for MongoDB ReplicaSet
SSL_DIR="./ssl/mongo"
mkdir -p "$SSL_DIR"

echo "=========================================================="
echo "🔐 MongoDB ReplicaSet TLS Certificate Generator"
echo "=========================================================="

check_certificates() {
    [ -f "$SSL_DIR/ca.pem" ] && \
    [ -f "$SSL_DIR/mongodb.pem" ] && \
    openssl verify -CAfile "$SSL_DIR/ca.pem" "$SSL_DIR/server.crt" >/dev/null 2>&1
}

if check_certificates; then
    echo "✅ MongoDB TLS certificates already valid. Skipping."
    exit 0
fi

echo ">> 📁 Generating CA..."
openssl genrsa 2048 > "$SSL_DIR/ca-key.pem" 2>/dev/null
openssl req -new -x509 -nodes -days 3650 \
    -key "$SSL_DIR/ca-key.pem" \
    -out "$SSL_DIR/ca.pem" \
    -subj "/CN=MongoDB-RS-CA"

echo ">> 📁 Generating Server Certificate..."
openssl req -newkey rsa:2048 -nodes -days 3650 \
    -keyout "$SSL_DIR/server.key" \
    -out "$SSL_DIR/server.csr" \
    -subj "/CN=mongo-server" 2>/dev/null

openssl x509 -req -in "$SSL_DIR/server.csr" -days 3650 \
    -CA "$SSL_DIR/ca.pem" \
    -CAkey "$SSL_DIR/ca-key.pem" \
    -set_serial 01 \
    -out "$SSL_DIR/server.crt" 2>/dev/null

# MongoDB uses combined PEM (cert+key)
cat "$SSL_DIR/server.crt" "$SSL_DIR/server.key" > "$SSL_DIR/mongodb.pem"

rm -f "$SSL_DIR/"*.csr
chmod 644 "$SSL_DIR/ca.pem" "$SSL_DIR/mongodb.pem" "$SSL_DIR/server.crt"
chmod 600 "$SSL_DIR/server.key"

echo ""
echo "✅ MongoDB TLS certificates generated in $SSL_DIR/"
echo "=========================================================="
