#!/bin/bash
set -euo pipefail

# Generate TLS certificates for MongoDB ReplicaSet
SSL_DIR="./ssl/mongo"
mkdir -p "$SSL_DIR"

echo "=========================================================="
echo "🔐 MongoDB ReplicaSet TLS Certificate Generator"
echo "=========================================================="

check_certificates() {
    [ -f "$1/ca.pem" ] && [ -f "$1/mongodb.pem" ] && \
    openssl verify -CAfile "$1/ca.pem" "$1/server.crt" >/dev/null 2>&1
}

if [ "${1:-}" != "--force" ] && check_certificates "$SSL_DIR" && check_certificates "./ssl/certs/mongo8"; then
    echo "✅ MongoDB TLS certificates already valid. Skipping."
    exit 0
fi

SANS="DNS:localhost,DNS:mongo1,DNS:mongo2,DNS:mongo3,DNS:mongo_n1,DNS:mongo_n2,DNS:mongo_n3,DNS:mongo8_n1,DNS:mongo8_n2,DNS:mongo8_n3,DNS:haproxy_mongo,DNS:haproxy_mongo8,IP:127.0.0.1"
for d in "$SSL_DIR" "./ssl/certs/mongo8"; do
    mkdir -p "$d"
    bash "$(dirname "$0")/gen_pki.sh" --dir "$d" --cn "MongoDB-RS" --mode single --combine mongodb.pem --san "$SANS" "$@"
done
