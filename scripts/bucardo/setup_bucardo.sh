#!/usr/bin/env bash
# Setup Bucardo 5 multi-master replication between two PG 17 (plperl) nodes.
set -euo pipefail

[ -f .env ] && { set -a; . ./.env; set +a; }
PG_USER="${PG_USER:-postgres}"
PG_DB="${PG_DB:-labdb}"
PG_PASS="${DB_ROOT_PASSWORD:-${PG_LAB_PASSWORD:-pg_poc_ephemeral}}"
ESC_PASS="${PG_PASS//\'/\'\'}"

qn() { docker exec -e PGPASSWORD="$PG_PASS" "$1" psql -v ON_ERROR_STOP=1 -U "$PG_USER" -d "${3:-$PG_DB}" -tAc "$2"; }

for n in bucardo_node1 bucardo_node2; do
    t=0
    until qn "$n" "SELECT 1;" >/dev/null 2>&1; do
        t=$((t+1)); [ "$t" -ge 30 ] && { echo "[FAIL] Timeout waiting for $n"; exit 1; }
        sleep 1
    done
    echo "[OK] $n ready"
done

for pair in "bucardo_node1:1" "bucardo_node2:2"; do
    n="${pair%%:*}"; start="${pair##*:}"
    qn "$n" "
        CREATE SEQUENCE IF NOT EXISTS accounts_id_seq INCREMENT BY 2 START WITH ${start};
        CREATE TABLE IF NOT EXISTS accounts (
            id BIGINT PRIMARY KEY DEFAULT nextval('accounts_id_seq'),
            owner TEXT NOT NULL, email TEXT UNIQUE,
            balance NUMERIC(14,2) NOT NULL DEFAULT 0,
            updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
        );
        ALTER SEQUENCE accounts_id_seq OWNED BY accounts.id;" >/dev/null
    echo "[OK] Schema ready on $n (step=2, start=$start)"
done

# Pre-create bucardo superuser with password on node1 so TCP auth works.
if [ "$(qn bucardo_node1 "SELECT count(*) FROM pg_roles WHERE rolname='bucardo';" postgres)" = "0" ]; then
    qn bucardo_node1 "CREATE ROLE bucardo WITH SUPERUSER LOGIN PASSWORD '${ESC_PASS}';" postgres >/dev/null
fi

docker exec -i bucardo_daemon bash -s <<EOF
set -euo pipefail
cat > /root/.pgpass <<PGP
bucardo_node1:5432:*:postgres:${PG_PASS}
bucardo_node1:5432:*:bucardo:${PG_PASS}
bucardo_node2:5432:*:postgres:${PG_PASS}
PGP
chmod 600 /root/.pgpass
cat > /root/.bucardorc <<BRC
dbhost=bucardo_node1
dbport=5432
dbname=bucardo
dbuser=bucardo
dbpass=${PG_PASS}
BRC
EOF

if [ "$(qn bucardo_node1 "SELECT count(*) FROM pg_database WHERE datname='bucardo';" postgres)" = "0" ]; then
    docker exec bucardo_daemon bash -lc "PGPASSWORD='$PG_PASS' bucardo install --batch --dbhost=bucardo_node1 --dbport=5432 --dbuser='$PG_USER' --dbname=postgres --piddir=/var/run/bucardo"
    echo "[OK] Bucardo metadata database installed on bucardo_node1"
fi

if ! docker exec bucardo_daemon bucardo list dbs | grep -q "Database: db1"; then
    docker exec bucardo_daemon bucardo add db db1 dbname="$PG_DB" host=bucardo_node1 port=5432 user="$PG_USER" pass="$PG_PASS"
    docker exec bucardo_daemon bucardo add db db2 dbname="$PG_DB" host=bucardo_node2 port=5432 user="$PG_USER" pass="$PG_PASS"
fi

if ! docker exec bucardo_daemon bucardo list dbgroup | grep -q "dbgroup: grp_mm"; then
    docker exec bucardo_daemon bucardo add dbgroup grp_mm db1:source db2:source
fi

if ! docker exec bucardo_daemon bucardo list sync | grep -q "Sync \"sync_mm\""; then
    docker exec bucardo_daemon bucardo add sync sync_mm dbs=grp_mm tables=public.accounts conflict_strategy=bucardo_latest
fi

docker exec bucardo_daemon bucardo stop >/dev/null 2>&1 || true
docker exec bucardo_daemon bucardo start
sleep 2
docker exec bucardo_daemon bucardo status sync_mm
echo "[OK] Bucardo multi-master sync_mm started"
