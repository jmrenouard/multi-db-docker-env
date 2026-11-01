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

if [ "${1:-}" != "--force" ] && check_certificates; then
    echo "✅ MongoDB TLS certificates already valid. Skipping."
    exit 0
fi

exec bash "$(dirname "$0")/gen_pki.sh" --dir "$SSL_DIR" --cn "MongoDB-RS" --mode single --combine mongodb.pem --san "DNS:localhost,DNS:mongo1,DNS:mongo2,DNS:mongo3,IP:127.0.0.1" "$@"
