#!/bin/bash

# Script to generate SSL certificates for MariaDB Cluster
# Highly inspired by MariaDB documentation and best practices

SSL_DIR="./ssl"
mkdir -p "$SSL_DIR"

echo "=========================================================="
echo "🔐 MariaDB SSL Certificate Generator"
echo "=========================================================="

# Function to check if certificates exist and are valid
check_certificates() {
    [ -f "$SSL_DIR/ca-cert.pem" ] && \
    [ -f "$SSL_DIR/ca-key.pem" ] && \
    [ -f "$SSL_DIR/server-cert.pem" ] && \
    [ -f "$SSL_DIR/server-key.pem" ] && \
    [ -f "$SSL_DIR/client-cert.pem" ] && \
    [ -f "$SSL_DIR/client-key.pem" ] && \
    openssl verify -CAfile "$SSL_DIR/ca-cert.pem" "$SSL_DIR/server-cert.pem" >/dev/null 2>&1 && \
    openssl verify -CAfile "$SSL_DIR/ca-cert.pem" "$SSL_DIR/client-cert.pem" >/dev/null 2>&1
}

if check_certificates; then
    echo "✅ SSL Certificates already exist and are valid. Skipping generation."
    echo "=========================================================="
    exit 0
fi

# 1. Create CA (Certificate Authority)
echo ">> 📁 Generating CA..."
openssl genrsa 2048 > "$SSL_DIR/ca-key.pem"
openssl req -new -x509 -nodes -days 3650 \
    -key "$SSL_DIR/ca-key.pem" \
    -out "$SSL_DIR/ca-cert.pem" \
    -subj "/CN=MariaDB-CA"

# 2. Create Server Certificate
echo ">> 📁 Generating Server Certificate..."
openssl req -newkey rsa:2048 -nodes -days 3650 \
    -keyout "$SSL_DIR/server-key.pem" \
    -out "$SSL_DIR/server-req.pem" \
    -subj "/CN=MariaDB-Server"

openssl x509 -req -in "$SSL_DIR/server-req.pem" -days 3650 \
    -CA "$SSL_DIR/ca-cert.pem" \
    -CAkey "$SSL_DIR/ca-key.pem" \
    -set_serial 01 \
    -out "$SSL_DIR/server-cert.pem"

# 3. Create Client Certificate
echo ">> 📁 Generating Client Certificate..."
openssl req -newkey rsa:2048 -nodes -days 3650 \
    -keyout "$SSL_DIR/client-key.pem" \
    -out "$SSL_DIR/client-req.pem" \
    -subj "/CN=MariaDB-Client"

openssl x509 -req -in "$SSL_DIR/client-req.pem" -days 3650 \
    -CA "$SSL_DIR/ca-cert.pem" \
    -CAkey "$SSL_DIR/ca-key.pem" \
    -set_serial 01 \
    -out "$SSL_DIR/client-cert.pem"

# Cleanup requests
rm -f "$SSL_DIR/"*.req "$SSL_DIR/"*.csr

# Set permissions
chmod 644 "$SSL_DIR/"*.pem

echo ""
echo "✅ SSL Certificates generated in $SSL_DIR/"
echo "=========================================================="
