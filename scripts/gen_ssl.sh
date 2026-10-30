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

if [ "${1:-}" != "--force" ] && check_certificates; then
    echo "✅ SSL Certificates already exist and are valid. Skipping generation."
    echo "=========================================================="
    exit 0
fi

exec "$(dirname "$0")/gen_pki.sh" --dir "$SSL_DIR" --cn "MariaDB" --san "DNS:localhost,DNS:mariadb,IP:127.0.0.1" "$@"
