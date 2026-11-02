#!/bin/bash
set -euo pipefail
# entrypoint_etcd.sh
# Manages dynamic startup of ETCD (new vs existing) to ensure HA.

ETCD_DATA_DIR="${ETCD_DATA_DIR:-/etcd-data}"
ETCD_NAME="${ETCD_NAME:-etcd1}"
INT_ETCD_CLIENT_PORT="${INT_ETCD_CLIENT_PORT:-2379}"
INT_ETCD_PEER_PORT="${INT_ETCD_PEER_PORT:-2380}"
VERIFY_CLIENT_CERT="${VERIFY_CLIENT_CERT:-true}"

# Detect cluster state
STATE="new"
if [ -d "${ETCD_DATA_DIR}/member" ]; then
    echo "🔄 Data directory detected. Switching to 'existing' state."
    STATE="existing"
fi

# Prevent conflict between environment variables and flags (ETCD 3.6+)
SAVED_DATA_DIR="${ETCD_DATA_DIR}"
SAVED_NAME="${ETCD_NAME}"
unset ETCD_DATA_DIR
unset ETCD_NAME
unset ETCD_LISTEN_CLIENT_URLS
unset ETCD_ADVERTISE_CLIENT_URLS
unset ETCD_LISTEN_PEER_URLS
unset ETCD_INITIAL_ADVERTISE_PEER_URLS
unset ETCD_INITIAL_CLUSTER
unset ETCD_INITIAL_CLUSTER_TOKEN
unset ETCD_INITIAL_CLUSTER_STATE

# Build security arguments
AUTH_FLAGS=""
if [ "${VERIFY_CLIENT_CERT}" = "true" ]; then
    AUTH_FLAGS="--peer-client-cert-auth"
fi

# Start SSH service for Ansible management
if [ -x /usr/sbin/sshd ]; then
    /usr/sbin/sshd 2>/dev/null || true
fi

# Build ETCD command with environment variables
# Execute ETCD
/usr/bin/etcd \
    --name "${SAVED_NAME}" \
    --data-dir "${SAVED_DATA_DIR}" \
    --listen-client-urls "https://0.0.0.0:${INT_ETCD_CLIENT_PORT}" \
    --advertise-client-urls "https://${SAVED_NAME}:${INT_ETCD_CLIENT_PORT}" \
    --listen-peer-urls "https://0.0.0.0:${INT_ETCD_PEER_PORT}" \
    --initial-advertise-peer-urls "https://${SAVED_NAME}:${INT_ETCD_PEER_PORT}" \
    --initial-cluster "etcd1=https://etcd1:${INT_ETCD_PEER_PORT},etcd2=https://etcd2:${INT_ETCD_PEER_PORT},etcd3=https://etcd3:${INT_ETCD_PEER_PORT}" \
    --initial-cluster-token "etcd-cluster-1" \
    --initial-cluster-state "${STATE}" \
    --cert-file "/certs/etcd-server.crt" \
    --key-file "/certs/etcd-server.key" \
    --trusted-ca-file "/certs/ca.crt" \
    --peer-cert-file "/certs/etcd-server.crt" \
    --peer-key-file "/certs/etcd-server.key" \
    --peer-trusted-ca-file "/certs/ca.crt" \
    $AUTH_FLAGS || { echo "⚠️ ETCD failed. Keeping container alive..."; tail -f /dev/null; }
