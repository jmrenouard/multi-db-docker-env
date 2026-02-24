#!/bin/bash
# setup_replication.sh
# Sets up PostgreSQL streaming replication from pg_node1 to pg_node2 and pg_node3
set -euo pipefail

PRIMARY_HOST="pg_node1"
PRIMARY_PORT=5432
REPLI_USER="repli_user"
REPLI_PASS="replipass"
STANDBYS=("pg_node2" "pg_node3")

echo "=========================================================="
echo "⚙️  PostgreSQL Streaming Replication Setup for PgPool-II"
echo "=========================================================="

echo "1. ⏳ Waiting for Primary to be ready (max 90s)..."
COUNTER=0
until docker exec "$PRIMARY_HOST" pg_isready -U postgres > /dev/null 2>&1 || [ $COUNTER -eq 90 ]; do
    printf "."
    sleep 1
    COUNTER=$((COUNTER + 1))
done
echo ""

if [ $COUNTER -eq 90 ]; then
    echo "❌ Primary node did not become ready in time."
    exit 1
fi
echo "✅ Primary is ready."

echo ""
echo "2. ⏳ Waiting for Primary to accept connections and init to complete (30s)..."
sleep 10

# Verify replication user exists
if docker exec "$PRIMARY_HOST" psql -U postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='$REPLI_USER'" | grep -q 1; then
    echo "✅ Replication user '$REPLI_USER' exists."
else
    echo ">> Creating replication user '$REPLI_USER'..."
    docker exec "$PRIMARY_HOST" psql -U postgres -c "CREATE ROLE $REPLI_USER WITH REPLICATION LOGIN PASSWORD '$REPLI_PASS';"
fi

# Ensure pg_hba.conf allows replication
if docker exec "$PRIMARY_HOST" grep -q "repli_user" /var/lib/postgresql/data/pg_hba.conf 2>/dev/null; then
    echo "✅ pg_hba.conf already configured for replication."
else
    echo ">> Configuring pg_hba.conf for replication access..."
    docker exec "$PRIMARY_HOST" bash -c "echo 'host replication repli_user 10.8.0.0/24 md5' >> /var/lib/postgresql/data/pg_hba.conf"
    docker exec "$PRIMARY_HOST" bash -c "echo 'host all all 10.8.0.0/24 md5' >> /var/lib/postgresql/data/pg_hba.conf"
    docker exec "$PRIMARY_HOST" psql -U postgres -c "SELECT pg_reload_conf();"
fi

# Create replication slots for each standby
for standby in "${STANDBYS[@]}"; do
    SLOT_NAME="${standby//-/_}_slot"
    SLOT_EXISTS=$(docker exec "$PRIMARY_HOST" psql -U postgres -tAc "SELECT 1 FROM pg_replication_slots WHERE slot_name='$SLOT_NAME'" 2>/dev/null || true)
    if [ "$SLOT_EXISTS" != "1" ]; then
        echo ">> Creating replication slot '$SLOT_NAME'..."
        docker exec "$PRIMARY_HOST" psql -U postgres -c "SELECT pg_create_physical_replication_slot('$SLOT_NAME');"
    else
        echo "✅ Replication slot '$SLOT_NAME' already exists."
    fi
done

echo ""
echo "3. ⛓️  Setting up Standby nodes..."

for standby in "${STANDBYS[@]}"; do
    SLOT_NAME="${standby//-/_}_slot"
    echo ""
    echo ">> Setting up standby: $standby..."

    # Stop the standby PostgreSQL
    echo ">> Stopping PostgreSQL on $standby..."
    docker exec "$standby" pg_ctl stop -D /var/lib/postgresql/data -m fast 2>/dev/null || true
    sleep 3

    # Clean the data directory completely (preserve mount point)
    echo ">> Cleaning data directory on $standby..."
    docker exec "$standby" bash -c 'find /var/lib/postgresql/data -mindepth 1 -delete 2>/dev/null || true'
    sleep 1

    # Take a base backup from the primary
    echo ">> Taking base backup from primary..."
    docker exec -e PGPASSWORD="$REPLI_PASS" "$standby" \
        pg_basebackup -h "$PRIMARY_HOST" -p "$PRIMARY_PORT" -U "$REPLI_USER" \
        -D /var/lib/postgresql/data -Fp -Xs -P -R -S "$SLOT_NAME"

    # Verify standby.signal exists (created by -R flag)
    if docker exec "$standby" test -f /var/lib/postgresql/data/standby.signal; then
        echo "✅ standby.signal created for $standby."
    else
        echo ">> Creating standby.signal..."
        docker exec "$standby" touch /var/lib/postgresql/data/standby.signal
    fi

    echo "✅ Base backup completed for $standby."
done

echo ""
echo "4. 🔄 Restarting standby containers..."
for standby in "${STANDBYS[@]}"; do
    docker restart "$standby"
done

echo ""
echo "5. ⏳ Waiting for standbys to come up (max 60s)..."
for standby in "${STANDBYS[@]}"; do
    COUNTER=0
    until docker exec "$standby" pg_isready -U postgres > /dev/null 2>&1 || [ $COUNTER -eq 60 ]; do
        printf "."
        sleep 1
        COUNTER=$((COUNTER + 1))
    done
    echo ""
    if [ $COUNTER -eq 60 ]; then
        echo "❌ Standby $standby did not become ready."
        exit 1
    fi
    echo "✅ Standby $standby is ready."
done

echo ""
echo "6. 📊 Verifying replication status..."
docker exec "$PRIMARY_HOST" psql -U postgres -c "SELECT client_addr, state, sync_state FROM pg_stat_replication;"

echo ""
echo "=========================================================="
echo "🏁 Replication Setup Finished"
echo "=========================================================="
