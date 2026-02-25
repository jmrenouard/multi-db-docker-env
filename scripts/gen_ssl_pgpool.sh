#!/bin/bash
set -euo pipefail

# Generate TLS certificates for PostgreSQL PgPool-II cluster
SSL_DIR="./ssl/pgpool"
mkdir -p "$SSL_DIR"

echo "=========================================================="
echo "🔐 PostgreSQL PgPool-II TLS Certificate Generator"
echo "=========================================================="

check_certificates() {
    [ -f "$SSL_DIR/ca-cert.pem" ] && \
    [ -f "$SSL_DIR/server.crt" ] && \
    [ -f "$SSL_DIR/server.key" ] && \
    openssl verify -CAfile "$SSL_DIR/ca-cert.pem" "$SSL_DIR/server.crt" >/dev/null 2>&1
}

if check_certificates; then
    echo "✅ PgPool TLS certificates already valid. Skipping."
    exit 0
fi

echo ">> 📁 Generating CA..."
openssl genrsa 2048 > "$SSL_DIR/ca-key.pem" 2>/dev/null
openssl req -new -x509 -nodes -days 3650 \
    -key "$SSL_DIR/ca-key.pem" \
    -out "$SSL_DIR/ca-cert.pem" \
    -subj "/CN=PostgreSQL-PgPool-CA"

echo ">> 📁 Generating Server Certificate (shared by PG nodes + PgPool)..."
openssl req -newkey rsa:2048 -nodes -days 3650 \
    -keyout "$SSL_DIR/server.key" \
    -out "$SSL_DIR/server.csr" \
    -subj "/CN=pg-server" 2>/dev/null

openssl x509 -req -in "$SSL_DIR/server.csr" -days 3650 \
    -CA "$SSL_DIR/ca-cert.pem" \
    -CAkey "$SSL_DIR/ca-key.pem" \
    -set_serial 01 \
    -out "$SSL_DIR/server.crt" 2>/dev/null

# PostgreSQL requires key to be readable only by owner
chmod 600 "$SSL_DIR/server.key"
rm -f "$SSL_DIR/"*.csr
chmod 644 "$SSL_DIR/ca-cert.pem" "$SSL_DIR/server.crt"

echo ""
echo "✅ PgPool TLS certificates generated in $SSL_DIR/"
echo "=========================================================="
