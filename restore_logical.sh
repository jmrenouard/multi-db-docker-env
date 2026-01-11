#!/bin/bash

# Configuration defaults
DB_USER="root"
DB_PASS="rootpass"
BACKUP_DIR="/backups"

# Helper for color output
echo_title() { echo -e "\n\033[1;36m>> $1\033[0m"; }
echo_success() { echo -e "\033[0;32m✅ $1\033[0m"; }
echo_error() { echo -e "\033[0;31m❌ $1\033[0m"; }

usage() {
    echo "Usage: $0 [galera|repli] [backup_filename.sql.gz]"
    echo ""
    echo "Description:"
    echo "  Restores a logical backup (mariadb) to the specified cluster."
    echo "  The backup file must exist in the container's /backups directory."
    exit 1
}

if [ "$#" -ne 2 ]; then usage; fi

CLUSTER=$1
FILENAME=$2

if [ "$CLUSTER" == "galera" ]; then
    # Restore can be done on any node in Galera, it will replicate
    CONTAINER="mariadb-galera_01-1"
elif [ "$CLUSTER" == "repli" ]; then
    # IMPORTANT: Restore MUST be done on the MASTER in replication
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
if ! docker exec "$CONTAINER" ls "$BACKUP_DIR/$FILENAME" >/dev/null 2>&1; then
    echo_error "File $BACKUP_DIR/$FILENAME not found in container $CONTAINER."
    echo "Available backups:"
    docker exec "$CONTAINER" ls -lh "$BACKUP_DIR"
    exit 1
fi

echo_title "Starting Logical Restoration for $CLUSTER..."
echo "Target Container: $CONTAINER (Master/Primary)"
echo "Source File: $BACKUP_DIR/$FILENAME"

# Execute restoration inside container
# We use unpigz to decompress on the fly
docker exec "$CONTAINER" bash -c "unpigz < $BACKUP_DIR/$FILENAME | mariadb -u$DB_USER -p$DB_PASS"

if [ $? -eq 0 ]; then
    echo_success "Restoration completed successfully!"
else
    echo_error "Restoration failed!"
    exit 1
fi
