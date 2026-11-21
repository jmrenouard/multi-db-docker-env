#!/bin/bash
# entrypoint_node.sh
# Prepare certificates and launch requested command (supervisord or pgbouncer)
# Adapted for multi-db-docker-env

set -euo pipefail

# Local directory for certificates
LOCAL_CERT_DIR="/etc/patroni/certs"
mkdir -p "$LOCAL_CERT_DIR"

# Start SSH service for Ansible management (root only)
if [ "$(id -u)" = "0" ] && [ -x /usr/sbin/sshd ]; then
    /usr/sbin/sshd 2>/dev/null || true
fi

echo "🔐 [ENTRYPOINT] Preparing certificates..."

# Copy certificates from /certs mount to local directory
if [ -d "/certs" ]; then
    cp /certs/*.crt "$LOCAL_CERT_DIR/" 2>/dev/null || true
    cp /certs/*.key "$LOCAL_CERT_DIR/" 2>/dev/null || true

    # Change ownership when running as root; non-root containers already own LOCAL_CERT_DIR
    if [ "$(id -u)" = "0" ]; then
        TARGET_USER="${RUN_AS_USER:-root}"
        chown -R "$TARGET_USER:$TARGET_USER" "$LOCAL_CERT_DIR"
        if id "postgres" &>/dev/null; then
            chown -R postgres:postgres /etc/patroni/certs
        fi
    fi
    chmod 755 /etc/patroni/certs
    chmod 600 /etc/patroni/certs/*.key 2>/dev/null || true
    chmod 644 /etc/patroni/certs/*.crt 2>/dev/null || true

    echo "✅ [ENTRYPOINT] Certificates prepared in /etc/patroni/certs"
else
    echo "⚠️  [ENTRYPOINT] Directory /certs not found."
fi

# Ensure PostgreSQL data directory exists with required 0700 permissions
mkdir -p /datas/pgdata
chmod 700 /datas/pgdata

# Map compose credentials and REST API TLS policy to native Patroni environment variables
export PATRONI_SUPERUSER_USERNAME="${POSTGRES_USER:-postgres}"
export PATRONI_SUPERUSER_PASSWORD="${POSTGRES_PASSWORD:-rootpass}"
export PATRONI_REPLICATION_USERNAME="${REPLICATOR_USER:-replicator}"
export PATRONI_REPLICATION_PASSWORD="${REPLICATOR_PASSWORD:-${POSTGRES_PASSWORD:-rootpass}}"
export PATRONI_RESTAPI_VERIFY_CLIENT="${PATRONI_VERIFY_CLIENT:-required}"

# Switch user if necessary to run final command
if [ "$(id -u)" = "0" ] && [ -n "${RUN_AS_USER:-}" ] && [ "$RUN_AS_USER" != "root" ]; then
    echo "👤 [ENTRYPOINT] Executing as $RUN_AS_USER..."
    exec su -s /bin/bash "$RUN_AS_USER" -c "$*"
else
    echo "👤 [ENTRYPOINT] Executing as $(id -un)..."
    exec "$@"
fi
