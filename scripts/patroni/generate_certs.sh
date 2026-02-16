#!/bin/bash
# generate_certs.sh
# Génération de certificats TLS avec SAN (Subject Alternative Names) pour le cluster.

CERT_DIR="${CERT_DIR:-./certs_patroni}"
mkdir -p "$CERT_DIR"

# Charger les variables d'environnement si le fichier .env existe
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# SANs par défaut
DEFAULT_SANS="DNS:localhost,DNS:etcd1,DNS:etcd2,DNS:etcd3,DNS:node1,DNS:node2,DNS:node3,DNS:haproxy,DNS:pgbouncer,IP:127.0.0.1"

# Fusionner avec EXTRA_SANS si défini
if [ -n "${EXTRA_SANS:-}" ]; then
    SANS="${DEFAULT_SANS},${EXTRA_SANS}"
else
    SANS="${DEFAULT_SANS}"
fi

# Identifiants par défaut s'ils ne sont pas dans .env
ETCD_PATRONI_USER="${ETCD_PATRONI_USER:-patroni}"
REPLICATOR_USER="${REPLICATOR_USER:-replicator}"

# Fichier de config OpenSSL temporaire pour les SAN
cat > $CERT_DIR/openssl.cnf <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
x509_extensions = v3_ca

[req_distinguished_name]
commonName = Common Name

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = $SANS

[v3_ca]
basicConstraints = CA:TRUE
keyUsage = cRLSign, keyCertSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
EOF

echo "🔐 Génération de l'autorité de certification (CA)..."
openssl genrsa -out $CERT_DIR/ca.key 2048
openssl req -x509 -new -nodes -key $CERT_DIR/ca.key -subj "/CN=Patroni-Cluster-CA" -days 3650 -out $CERT_DIR/ca.crt -config $CERT_DIR/openssl.cnf -extensions v3_ca

generate_cert_with_cn() {
    local name=$1
    local cn=$2
    echo "📜 Génération du certificat pour $name (CN=$cn)..."
    openssl genrsa -out $CERT_DIR/$name.key 2048
    openssl req -new -key $CERT_DIR/$name.key -subj "/CN=$cn" -out $CERT_DIR/$name.csr -config $CERT_DIR/openssl.cnf
    openssl x509 -req -in $CERT_DIR/$name.csr -CA $CERT_DIR/ca.crt -CAkey $CERT_DIR/ca.key -CAcreateserial -out $CERT_DIR/$name.crt -days 365 -sha256 -extfile $CERT_DIR/openssl.cnf -extensions v3_req
}

generate_cert() {
    generate_cert_with_cn "$1" "$1"
}

# Certificats pour ETCD
generate_cert "etcd-server"
generate_cert_with_cn "etcd-client" "${ETCD_PATRONI_USER}"

# Certificats pour Patroni API
generate_cert "patroni-api"

# Certificats pour PostgreSQL
generate_cert "postgresql-server"
generate_cert_with_cn "postgresql-client" "${REPLICATOR_USER}"

# Certificats pour PgBouncer
generate_cert "pgbouncer"

# Fichier PEM combiné pour HAProxy (Certificat + Clé)
echo "📜 Génération du PEM combiné pour HAProxy..."
cat $CERT_DIR/postgresql-server.crt $CERT_DIR/postgresql-server.key > $CERT_DIR/haproxy.pem

echo "✅ Certificats générés dans $CERT_DIR"

chmod 700 $CERT_DIR
chmod 600 $CERT_DIR/*.key
chmod 644 $CERT_DIR/*.crt
rm -f $CERT_DIR/openssl.cnf $CERT_DIR/*.csr $CERT_DIR/ca.srl
