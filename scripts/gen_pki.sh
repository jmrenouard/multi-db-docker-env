#!/bin/bash
# scripts/gen_pki.sh — Unified PKI & SAN certificate generator
set -euo pipefail

DIR="./ssl"; CN="MariaDB"; SANS="DNS:localhost,IP:127.0.0.1"; MODE="mariadb"; COMBINE=""; CHOWN_U=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dir) DIR="$2"; shift 2 ;;
        --cn) CN="$2"; shift 2 ;;
        --san) SANS="$2"; shift 2 ;;
        --mode) MODE="$2"; shift 2 ;;
        --combine) COMBINE="$2"; shift 2 ;;
        --chown) CHOWN_U="$2"; shift 2 ;;
        --force) shift 1 ;;
        *) shift 1 ;;
    esac
done

mkdir -p "$DIR"
CFG="$DIR/san.cnf"
cat <<EOF > "$CFG"
[req]
distinguished_name = req_dn
x509_extensions = v3_ca
[req_dn]
commonName = Common Name
[v3_req]
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
subjectAltName = $SANS
[v3_ca]
basicConstraints = critical, CA:TRUE
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
subjectAltName = $SANS
EOF

CA_CERT="$DIR/ca-cert.pem"; CA_KEY="$DIR/ca-key.pem"
[ "$MODE" = "single" ] && CA_CERT="$DIR/ca.pem"
openssl genrsa 2048 > "$CA_KEY" 2>/dev/null
openssl req -new -x509 -nodes -days 3650 -key "$CA_KEY" -out "$CA_CERT" -subj "/CN=${CN}-CA" -config "$CFG" -extensions v3_ca 2>/dev/null

SRV_CERT="$DIR/server-cert.pem"; SRV_KEY="$DIR/server-key.pem"
if [ "$MODE" = "single" ] || [ "$MODE" = "standard" ]; then
    SRV_CERT="$DIR/server.crt"; SRV_KEY="$DIR/server.key"
fi

sign() {
    local k="$1" c="$2" sub="$3"
    openssl req -newkey rsa:2048 -nodes -days 3650 -keyout "$k" -out "$DIR/t.csr" -subj "$sub" -config "$CFG" -reqexts v3_req 2>/dev/null
    openssl x509 -req -in "$DIR/t.csr" -days 3650 -CA "$CA_CERT" -CAkey "$CA_KEY" -CAcreateserial -out "$c" -extfile "$CFG" -extensions v3_req 2>/dev/null
}

sign "$SRV_KEY" "$SRV_CERT" "/CN=${CN}-Server"
if [ "$MODE" = "mariadb" ]; then
    sign "$DIR/client-key.pem" "$DIR/client-cert.pem" "/CN=${CN}-Client"
    chmod 600 "$DIR/client-key.pem" 2>/dev/null || true
    chmod 644 "$DIR/client-cert.pem" 2>/dev/null || true
fi

[ -n "$COMBINE" ] && cat "$SRV_CERT" "$SRV_KEY" > "$DIR/$COMBINE" && (chmod 600 "$DIR/$COMBINE" 2>/dev/null || true)
chmod 600 "$CA_KEY" "$SRV_KEY" 2>/dev/null || true
chmod 644 "$CA_CERT" "$SRV_CERT" 2>/dev/null || true

rm -f "$CFG" "$DIR"/*.csr "$DIR"/*.srl "$DIR"/t.csr

if [ -n "$CHOWN_U" ]; then
    if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
        docker run --rm -v "$(pwd)/$DIR:/ssl" alpine sh -c "chown -R $CHOWN_U /ssl && chmod 755 /ssl && chmod 600 /ssl/*key* /ssl/*.key 2>/dev/null || true" 2>/dev/null || true
    else
        chown -R "$CHOWN_U" "$DIR" 2>/dev/null || true
    fi
fi

echo "✅ PKI certificates ($CN) generated in $DIR/"