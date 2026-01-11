#!/bin/bash

# Configuration defaults
DB_USER="root"
DB_PASS="rootpass"
BACKUP_DIR="/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Helper for color output
echo_title() { echo -e "\n\033[1;36m>> $1\033[0m"; }
echo_success() { echo -e "\033[0;32m✅ $1\033[0m"; }
echo_error() { echo -e "\033[0;31m❌ $1\033[0m"; }

usage() {
    echo "Usage: $0 [galera|repli] [database_name|--all-databases]"
    echo ""
    echo "Description:"
    echo "  Performs a logical backup (mariadb-dump) of the specified cluster."
    echo "  Backups are stored in the cluster's respective backup volume."
    exit 1
}

if [ "$#" -lt 1 ]; then usage; fi

CLUSTER=$1
DB_TARGET=${2:-"--all-databases"}

if [ "$CLUSTER" == "galera" ]; then
    CONTAINER="mariadb-galera_01-1"
    FILE_PREFIX="galera_logical"
elif [ "$CLUSTER" == "repli" ]; then
    # We prefer backing up from a slave (02 or 03) to reduce load on master
    CONTAINER="mariadb-mariadb_02-1"
    FILE_PREFIX="repli_logical"
else
    usage
fi

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "$CONTAINER"; then
    echo_error "Container $CONTAINER is not running. Please start the $CLUSTER cluster first."
    exit 1
fi

FILENAME="${FILE_PREFIX}_${TIMESTAMP}.sql.gz"

echo_title "Starting Logical Backup for $CLUSTER..."
echo "Target Container: $CONTAINER"
echo "Database: $DB_TARGET"
echo "Destination: $BACKUP_DIR/$FILENAME"

if [ "$DB_TARGET" != "--all-databases" ]; then
    DUMP_OPTS="--databases $DB_TARGET"
else
    DUMP_OPTS="--all-databases"
fi

# Execute dump inside container and compress
# We use --single-transaction for InnoDB consistency
# We use --routines --triggers --events for a complete dump
docker exec "$CONTAINER" bash -c "mariadb-dump -u$DB_USER -p$DB_PASS --single-transaction --routines --triggers --events $DUMP_OPTS | pigz > $BACKUP_DIR/$FILENAME"

if [ $? -eq 0 ]; then
    echo_success "Backup completed successfully!"
    echo "File info:"
    docker exec "$CONTAINER" ls -lh "$BACKUP_DIR/$FILENAME"
else
    echo_error "Backup failed!"
    exit 1
fi
