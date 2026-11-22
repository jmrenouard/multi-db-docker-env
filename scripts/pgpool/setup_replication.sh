#!/bin/bash
# setup_replication.sh
# Sets up PostgreSQL streaming replication from pg_node1 to pg_node2 and pg_node3
set -euo pipefail

if [ -f .env ]; then
    set -a
    . ./.env
    set +a
fi

PRIMARY_HOST="pg_node1"
PRIMARY_PORT=5432
REPL_USER="${REPL_USER:-repl_user}"
REPL_PASS="${REPL_PASS:-repl_pass}"
REPLI_USER="$REPL_USER"
REPLI_PASS="$REPL_PASS"
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
ESC_USER="${REPLI_USER//\'/\'\'}"
ESC_PASS="${REPLI_PASS//\'/\'\'}"
if docker exec "$PRIMARY_HOST" psql -U postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='${ESC_USER}'" | grep -q 1; then
    echo "✅ Replication user '$REPLI_USER' exists."
else
    echo ">> Creating replication user '$REPLI_USER'..."
    docker exec "$PRIMARY_HOST" psql -U postgres -v ON_ERROR_STOP=1 -c "CREATE ROLE \"${REPLI_USER//\"/\"\"}\" WITH REPLICATION LOGIN PASSWORD '${ESC_PASS}';"
fi

# Ensure pg_hba.conf allows replication
if docker exec "$PRIMARY_HOST" grep -q "$REPLI_USER" /var/lib/postgresql/data/pg_hba.conf 2>/dev/null; then
    echo "✅ pg_hba.conf already configured for replication."
else
    echo ">> Configuring pg_hba.conf for replication access..."
    docker exec "$PRIMARY_HOST" bash -c "echo 'host replication $REPLI_USER 10.8.0.0/24 md5' >> /var/lib/postgresql/data/pg_hba.conf"
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

NET="$(docker inspect -f '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}' "$PRIMARY_HOST" | awk '{print $1}')"
for standby in "${STANDBYS[@]}"; do
    SLOT_NAME="${standby//-/_}_slot"
    echo ""
    echo ">> Setting up standby: $standby..."

    # Stop standby gracefully so PGDATA is never wiped beneath a live postgres process
    docker stop "$standby" >/dev/null
    docker run --rm --volumes-from "$standby" --network "$NET" \
        -e PGPASSWORD="$REPLI_PASS" -e P_HOST="$PRIMARY_HOST" -e P_PORT="$PRIMARY_PORT" \
        -e R_USER="$REPLI_USER" -e R_SLOT="$SLOT_NAME" postgres:17 \
        bash -c 'find /var/lib/postgresql/data -mindepth 1 -delete && chown postgres:postgres /var/lib/postgresql/data && chmod 700 /var/lib/postgresql/data && exec gosu postgres pg_basebackup -h "$P_HOST" -p "$P_PORT" -U "$R_USER" -D /var/lib/postgresql/data -Fp -Xs -P -R -S "$R_SLOT"'
    docker start "$standby" >/dev/null
    echo "✅ Base backup completed and $standby started."
done

echo ""
echo "4. ⏳ Waiting for standbys to come up (max 60s)..."
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

echo ">> Restarting pgpool to refresh backend status..."
docker restart pgpool >/dev/null

echo ""
echo "6. 📊 Verifying replication status..."
docker exec "$PRIMARY_HOST" psql -U postgres -c "SELECT client_addr, state, sync_state FROM pg_stat_replication;"

echo ""
echo "=========================================================="
echo "🏁 Replication Setup Finished"
echo "=========================================================="
