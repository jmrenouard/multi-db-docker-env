#!/bin/bash
set -euo pipefail

# Generate TLS certificates for PostgreSQL PgPool-II cluster
SSL_DIR="./ssl/pgpool"
mkdir -p "$SSL_DIR"
if [ -d "$SSL_DIR" ]; then
    if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
        docker run --rm -v "$(pwd)/$SSL_DIR:/ssl" alpine sh -c "chmod -R 755 /ssl 2>/dev/null || true" 2>/dev/null || true
    else
        chmod -R 755 "$SSL_DIR" 2>/dev/null || true
    fi
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

if [ "${1:-}" != "--force" ] && check_certificates; then
    echo "✅ PgPool TLS certificates already valid. Skipping."
    exit 0
fi

exec bash "$(dirname "$0")/gen_pki.sh" --dir "$SSL_DIR" --cn "PostgreSQL-PgPool" --mode standard --chown 999:999 --san "DNS:localhost,DNS:pgpool,DNS:node1,DNS:node2,DNS:node3,IP:127.0.0.1" "$@"
