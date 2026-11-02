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
    
    # Change ownership of directory and files for target user
    TARGET_USER="${RUN_AS_USER:-root}"
    chown -R "$TARGET_USER:$TARGET_USER" "$LOCAL_CERT_DIR"
    # Always ensure postgres can read certificates
    if id "postgres" &>/dev/null; then
        chown -R postgres:postgres /etc/patroni/certs
    fi
    chmod 755 /etc/patroni/certs
    chmod 600 /etc/patroni/certs/*.key 2>/dev/null || true
    chmod 644 /etc/patroni/certs/*.crt 2>/dev/null || true

    echo "✅ [ENTRYPOINT] Certificates prepared in /etc/patroni/certs"
else
    echo "⚠️  [ENTRYPOINT] Directory /certs not found."
fi

# Switch user if necessary to run final command
if [ -n "${RUN_AS_USER:-}" ] && [ "$RUN_AS_USER" != "root" ]; then
    echo "👤 [ENTRYPOINT] Executing as $RUN_AS_USER..."
    exec su -s /bin/bash "$RUN_AS_USER" -c "$*"
else
    echo "👤 [ENTRYPOINT] Executing as root..."
    exec "$@"
fi
