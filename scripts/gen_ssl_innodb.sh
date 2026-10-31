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

if [ "${1:-}" != "--force" ] && check_certificates; then
    echo "✅ InnoDB TLS certificates already valid. Skipping."
    exit 0
fi

exec bash "$(dirname "$0")/gen_pki.sh" --dir "$SSL_DIR" --cn "MySQL-InnoDB" --san "DNS:localhost,DNS:mysql1,DNS:mysql2,DNS:mysql3,IP:127.0.0.1" "$@"
