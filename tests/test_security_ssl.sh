#!/bin/bash
set -euo pipefail

# MariaDB SSL Security Audit
echo "=========================================================="
echo "🛡️  MariaDB SSL Security Audit"
echo "=========================================================="

SSL_DIR="./ssl"
if [ ! -d "$SSL_DIR" ]; then
    echo "❌ SSL directory not found. Please run 'make gen-ssl' first."
    exit 1
fi

echo "1. Checking certificate chaining..."
if openssl verify -CAfile "$SSL_DIR/ca-cert.pem" "$SSL_DIR/server-cert.pem" > /dev/null 2>&1; then
    echo "✅ Server certificate signed by CA"
else
    echo "❌ Server certificate NOT signed by CA"
    exit 1
fi

if openssl verify -CAfile "$SSL_DIR/ca-cert.pem" "$SSL_DIR/client-cert.pem" > /dev/null 2>&1; then
    echo "✅ Client certificate signed by CA"
else
    echo "❌ Client certificate NOT signed by CA"
    exit 1
fi

echo -e "\n2. Checking expiry dates..."
for f in "$SSL_DIR"/*.pem; do
    if [[ "$f" == *"-cert.pem" ]]; then
        EXPIRY=$(openssl x509 -enddate -noout -in "$f" | cut -d= -f2)
        echo "✅ $f expires on: $EXPIRY"
    fi
done

echo -e "\n3. Checking key consistency..."
CERT_PUB=$(openssl x509 -noout -pubkey -in "$SSL_DIR/server-cert.pem" | openssl md5)
KEY_PUB=$(openssl rsa -pubout -in "$SSL_DIR/server-key.pem" 2>/dev/null | openssl md5)

if [ "$CERT_PUB" == "$KEY_PUB" ]; then
    echo "✅ Server key matches certificate (Hash: $(echo $CERT_PUB | awk '{print $NF}'))"
else
    echo "❌ Server key mismatch!"
    echo "   Cert Hash: $CERT_PUB"
    echo "   Key Hash:  $KEY_PUB"
    exit 1
fi

echo -e "\n=========================================================="
echo "🎉 SSL Security Audit Passed!"
echo "=========================================================="
