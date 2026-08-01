#!/bin/bash
set -euo pipefail

# Generate TLS certificates for PostgreSQL PgPool-II cluster
SSL_DIR="./ssl/pgpool"
mkdir -p "$SSL_DIR"
if [ -d "$SSL_DIR" ]; then
    docker run --rm -v "$(pwd)/$SSL_DIR:/ssl" alpine sh -c "chmod -R 777 /ssl 2>/dev/null || true" 2>/dev/null || true
fi

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

# PostgreSQL requires key to be owned by database user (postgres UID 999) with 0600 mode
rm -f "$SSL_DIR/"*.csr
docker run --rm -v "$(pwd)/$SSL_DIR:/ssl" alpine sh -c "chown -R 999:999 /ssl && chmod 600 /ssl/server.key && chmod 666 /ssl/ca-cert.pem /ssl/server.crt /ssl/ca-key.pem 2>/dev/null && chmod 777 /ssl" 2>/dev/null || true

echo ""
echo "✅ PgPool TLS certificates generated in $SSL_DIR/"
echo "=========================================================="
