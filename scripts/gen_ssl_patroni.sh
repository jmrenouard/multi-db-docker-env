#!/bin/bash
set -euo pipefail

# Generate TLS certificates for Patroni PostgreSQL cluster (Docker-native)
SSL_DIR="./ssl/patroni"
mkdir -p "$SSL_DIR"

echo "=========================================================="
echo "🔐 Patroni PostgreSQL TLS Certificate Generator"
echo "=========================================================="

if ! CERT_DIR="certs_patroni" bash ./scripts/patroni/generate_certs.sh; then
    echo "❌ ERROR: Certificate generation failed in generate_certs.sh" >&2
    exit 1
fi

if [ -d "certs_patroni" ]; then
    cp -f certs_patroni/ca.crt "$SSL_DIR/ca-cert.pem"
    cp -f certs_patroni/postgresql-server.crt "$SSL_DIR/server.crt"
    cp -f certs_patroni/postgresql-server.key "$SSL_DIR/server.key"
    chmod 600 "$SSL_DIR/server.key" certs_patroni/postgresql-server.key 2>/dev/null || true
    chmod 644 "$SSL_DIR/server.crt" "$SSL_DIR/ca-cert.pem" 2>/dev/null || true
else
    echo "❌ ERROR: Directory certs_patroni was not created" >&2
    exit 1
fi

echo "✅ Patroni TLS certificates generated in $SSL_DIR/ and certs_patroni/"
echo "=========================================================="
