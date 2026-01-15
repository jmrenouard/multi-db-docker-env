#!/bin/bash

# Configuration defaults
DB_USER="root"
DB_PASS="rootpass"
BACKUP_BASE_DIR="/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Helper for color output
echo_title() { echo -e "\n\033[1;36m>> $1\033[0m"; }
echo_success() { echo -e "\033[0;32m✅ $1\033[0m"; }
echo_error() { echo -e "\033[0;31m❌ $1\033[0m"; }

usage() {
    echo "Usage: $0 [galera|repli]"
    echo ""
    echo "Description:"
    echo "  Performs a physical backup (mariabackup) of the specified cluster."
    echo "  The backup is prepared and then compressed into a .tar.gz file."
    exit 1
}

if [ "$#" -ne 1 ]; then usage; fi

CLUSTER=$1

if [ "$CLUSTER" == "galera" ]; then
    CONTAINER="mariadb-galera_01-1"
    FILE_PREFIX="galera_physical"
elif [ "$CLUSTER" == "repli" ]; then
    # We prefer backing up from a slave (02 or 03) to reduce load on master
    # and because mariabackup on slaves handles replication info well
    CONTAINER="mariadb-mariadb_02-1"
    FILE_PREFIX="repli_physical"
else
    usage
fi

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "$CONTAINER"; then
    echo_error "Container $CONTAINER is not running. Please start the $CLUSTER cluster first."
    exit 1
fi

BACKUP_DIR="${BACKUP_BASE_DIR}/phys_tmp_${TIMESTAMP}"
FILENAME="${FILE_PREFIX}_${TIMESTAMP}.tar.gz"

echo_title "Starting Physical Backup for $CLUSTER..."
echo "Target Container: $CONTAINER"
echo "Temporary Dir: $BACKUP_DIR"
echo "Final Archive: ${BACKUP_BASE_DIR}/${FILENAME}"

# 1. Run mariabackup
echo ">> 📁 Running mariabackup..."
docker exec "$CONTAINER" mariabackup --backup \
    --user="$DB_USER" \
    --password="$DB_PASS" \
    --target-dir="$BACKUP_DIR"

if [ $? -ne 0 ]; then
    echo_error "Physical backup failed during capture!"
    exit 1
fi

# 2. Prepare the backup
echo ">> ⚙️ Preparing the backup (apply-log)..."
docker exec "$CONTAINER" mariabackup --prepare --target-dir="$BACKUP_DIR"

if [ $? -ne 0 ]; then
    echo_error "Physical backup failed during preparation!"
    exit 1
fi

# 3. Compress the backup
echo ">> 📦 Compressing backup directory..."
docker exec "$CONTAINER" bash -c "cd $BACKUP_BASE_DIR && tar -I pigz -cf $FILENAME $(basename $BACKUP_DIR) && rm -rf $(basename $BACKUP_DIR)"

if [ $? -eq 0 ]; then
    echo_success "Physical backup completed successfully!"
    echo "File info:"
    docker exec "$CONTAINER" ls -lh "$BACKUP_BASE_DIR/$FILENAME"
else
    echo_error "Compression failed!"
    exit 1
fi
