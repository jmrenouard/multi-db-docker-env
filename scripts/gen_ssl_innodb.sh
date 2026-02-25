#!/bin/bash
set -euo pipefail

# Generate TLS certificates for MySQL InnoDB Cluster
SSL_DIR="./ssl/innodb"
mkdir -p "$SSL_DIR"

echo "=========================================================="
echo "🔐 MySQL InnoDB Cluster TLS Certificate Generator"
echo "=========================================================="

check_certificates() {
    [ -f "$SSL_DIR/ca-cert.pem" ] && \
    [ -f "$SSL_DIR/server-cert.pem" ] && \
    [ -f "$SSL_DIR/server-key.pem" ] && \
    openssl verify -CAfile "$SSL_DIR/ca-cert.pem" "$SSL_DIR/server-cert.pem" >/dev/null 2>&1
}

if check_certificates; then
    echo "✅ InnoDB TLS certificates already valid. Skipping."
    exit 0
fi

echo ">> 📁 Generating CA..."
openssl genrsa 2048 > "$SSL_DIR/ca-key.pem" 2>/dev/null
openssl req -new -x509 -nodes -days 3650 \
    -key "$SSL_DIR/ca-key.pem" \
    -out "$SSL_DIR/ca-cert.pem" \
    -subj "/CN=MySQL-InnoDB-CA"

echo ">> 📁 Generating Server Certificate..."
openssl req -newkey rsa:2048 -nodes -days 3650 \
    -keyout "$SSL_DIR/server-key.pem" \
    -out "$SSL_DIR/server-req.pem" \
    -subj "/CN=MySQL-InnoDB-Server" 2>/dev/null

openssl x509 -req -in "$SSL_DIR/server-req.pem" -days 3650 \
    -CA "$SSL_DIR/ca-cert.pem" \
    -CAkey "$SSL_DIR/ca-key.pem" \
    -set_serial 01 \
    -out "$SSL_DIR/server-cert.pem" 2>/dev/null

echo ">> 📁 Generating Client Certificate..."
openssl req -newkey rsa:2048 -nodes -days 3650 \
    -keyout "$SSL_DIR/client-key.pem" \
    -out "$SSL_DIR/client-req.pem" \
    -subj "/CN=MySQL-InnoDB-Client" 2>/dev/null

openssl x509 -req -in "$SSL_DIR/client-req.pem" -days 3650 \
    -CA "$SSL_DIR/ca-cert.pem" \
    -CAkey "$SSL_DIR/ca-key.pem" \
    -set_serial 02 \
    -out "$SSL_DIR/client-cert.pem" 2>/dev/null

rm -f "$SSL_DIR/"*.req "$SSL_DIR/"*.csr
chmod 644 "$SSL_DIR/"*.pem

echo ""
echo "✅ InnoDB TLS certificates generated in $SSL_DIR/"
echo "=========================================================="
