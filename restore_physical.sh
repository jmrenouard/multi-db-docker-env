#!/bin/bash

# Configuration defaults
BACKUP_BASE_DIR="/backups"
DATA_DIR="/var/lib/mysql"

# Helper for color output
echo_title() { echo -e "\n\033[1;36m>> $1\033[0m"; }
echo_success() { echo -e "\033[0;32m✅ $1\033[0m"; }
echo_error() { echo -e "\033[0;31m❌ $1\033[0m"; }

usage() {
    echo "Usage: $0 [galera|repli] [backup_filename.tar.gz]"
    echo ""
    echo "Description:"
    echo "  Restores a physical backup (mariabackup) to the specified cluster."
    echo "  Restoration is performed on Galera Node 1 or Replication Master."
    echo "  WARNING: This will STOP the MariaDB process and OVERWRITE the current data."
    exit 1
}

if [ "$#" -ne 2 ]; then usage; fi

CLUSTER=$1
FILENAME=$2

if [ "$CLUSTER" == "galera" ]; then
    CONTAINER="mariadb-galera_01-1"
elif [ "$CLUSTER" == "repli" ]; then
    CONTAINER="mariadb-mariadb_01-1"
else
    usage
fi

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "$CONTAINER"; then
    echo_error "Container $CONTAINER is not running. Please start the $CLUSTER cluster first."
    exit 1
fi

# Check if file exists in the container
if ! docker exec "$CONTAINER" ls "$BACKUP_BASE_DIR/$FILENAME" >/dev/null 2>&1; then
    echo_error "File $BACKUP_BASE_DIR/$FILENAME not found in container $CONTAINER."
    echo "Available physical backups:"
    docker exec "$CONTAINER" ls -lh "$BACKUP_BASE_DIR"/*.tar.gz 2>/dev/null
    exit 1
fi

echo_title "Starting Physical Restoration for $CLUSTER..."
echo "Target Container: $CONTAINER"
echo "Source File: $BACKUP_BASE_DIR/$FILENAME"

# 1. Stop MariaDB
echo ">> 🛑 Stopping MariaDB via Supervisor..."
docker exec "$CONTAINER" supervisorctl stop mariadb

# 2. Extract backup
TMP_RESTORE_DIR="${BACKUP_BASE_DIR}/restore_tmp_$(date +%s)"
echo ">> 📦 Extracting archive to $TMP_RESTORE_DIR..."
docker exec "$CONTAINER" mkdir -p "$TMP_RESTORE_DIR"
docker exec "$CONTAINER" tar -I pigz -xf "${BACKUP_BASE_DIR}/${FILENAME}" -C "$TMP_RESTORE_DIR" --strip-components=1

# 3. Clear current DATA_DIR
echo ">> 🗑️ Cleaning current data directory $DATA_DIR..."
docker exec "$CONTAINER" bash -c "rm -rf ${DATA_DIR}/*"

# 4. Copy back
echo ">> 📋 Running mariabackup --copy-back..."
docker exec "$CONTAINER" mariabackup --copy-back --target-dir="$TMP_RESTORE_DIR"

# 5. Fix permissions
echo ">> 🔑 Setting permissions to mysql:mysql..."
docker exec "$CONTAINER" chown -R mysql:mysql "$DATA_DIR"

# 6. Cleanup temp dir
echo ">> 🧹 Cleaning up temporary extraction directory..."
docker exec "$CONTAINER" rm -rf "$TMP_RESTORE_DIR"

# 7. Start MariaDB
echo ">> 🚀 Starting MariaDB via Supervisor..."
docker exec "$CONTAINER" supervisorctl start mariadb

if [ $? -eq 0 ]; then
    echo_success "Physical restoration completed successfully!"
    echo "Note: If this is a cluster, other nodes may need to perform an SST to sync."
else
    echo_error "Restoration failed!"
    exit 1
fi
