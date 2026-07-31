#!/bin/bash
set -euo pipefail

# Generate TLS certificates for Patroni PostgreSQL cluster (Docker-native)
SSL_DIR="./ssl/patroni"
mkdir -p "$SSL_DIR"

echo "=========================================================="
echo "🔐 Patroni PostgreSQL TLS Certificate Generator"
echo "=========================================================="

CERT_DIR="certs_patroni" bash ./scripts/patroni/generate_certs.sh

if [ -d "certs_patroni" ]; then
    cp -f certs_patroni/ca.crt "$SSL_DIR/ca-cert.pem" 2>/dev/null || true
    cp -f certs_patroni/postgresql-server.crt "$SSL_DIR/server.crt" 2>/dev/null || true
    cp -f certs_patroni/postgresql-server.key "$SSL_DIR/server.key" 2>/dev/null || true
fi

echo "✅ Patroni TLS certificates generated in $SSL_DIR/ and certs_patroni/"
echo "=========================================================="
