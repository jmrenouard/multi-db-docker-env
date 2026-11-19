#!/usr/bin/env bash
# Setup 3-node pgEdge Spock 5 + Snowflake full active-active mesh.
set -euo pipefail

[ -f .env ] && { set -a; . ./.env; set +a; }
PG_USER="${PG_USER:-postgres}"
PG_DB="${PG_DB:-labdb}"
PG_PASS="${DB_ROOT_PASSWORD:-${PG_LAB_PASSWORD:-pg_poc_ephemeral}}"
ESC_PASS="${PG_PASS//\'/\'\'}"

qn() { docker exec -e PGPASSWORD="$PG_PASS" "$1" psql -v ON_ERROR_STOP=1 -U "$PG_USER" -d "$PG_DB" -tAc "$2"; }

for i in 1 2 3; do
    n="pgedge_node${i}"; t=0
    until qn "$n" "SELECT 1;" >/dev/null 2>&1; do
        t=$((t+1)); [ "$t" -ge 40 ] && { echo "[FAIL] Timeout waiting for $n"; exit 1; }
        sleep 1
    done
    docker exec "$n" sh -c "grep -q '^host replication all all' /var/lib/pgsql/17/data/pg_hba.conf || echo 'host replication all all scram-sha-256' >> /var/lib/pgsql/17/data/pg_hba.conf"
    qn "$n" "SELECT pg_reload_conf();" >/dev/null
    qn "$n" "CREATE EXTENSION IF NOT EXISTS spock; CREATE EXTENSION IF NOT EXISTS snowflake;" >/dev/null
    if [ "$(qn "$n" "SELECT count(*) FROM spock.node WHERE node_name='n${i}';")" = "0" ]; then
        qn "$n" "SELECT spock.node_create(node_name:='n${i}', dsn:='host=${n} port=5432 dbname=${PG_DB} user=${PG_USER} password=${ESC_PASS}');" >/dev/null
    fi
    echo "[OK] $n initialized (spock + snowflake.node=$i)"
done

for dst in 1 2 3; do
    for src in 1 2 3; do
        [ "$dst" = "$src" ] && continue
        dn="pgedge_node${dst}"; sn="pgedge_node${src}"; sub="sub_n${dst}_n${src}"
        if [ "$(qn "$dn" "SELECT count(*) FROM spock.subscription WHERE sub_name='${sub}';")" = "0" ]; then
            qn "$dn" "SELECT spock.sub_create(subscription_name:='${sub}', provider_dsn:='host=${sn} port=5432 dbname=${PG_DB} user=${PG_USER} password=${ESC_PASS}');" >/dev/null
        fi
    done
done

for i in 1 2 3; do
    n="pgedge_node${i}"; t=0
    until [ "$(qn "$n" "SELECT count(*) FROM spock.sub_show_status() WHERE status='replicating';")" = "2" ] 2>/dev/null; do
        t=$((t+1)); [ "$t" -ge 30 ] && { echo "[FAIL] Mesh not replicating on $n"; exit 1; }
        sleep 1
    done
    echo "[OK] Mesh replicating on $n (2/2 peers)"
done

# Create schema on n1; auto-DDL replication propagates to n2 and n3.
qn "pgedge_node1" "
    CREATE TABLE IF NOT EXISTS accounts (
        id BIGINT PRIMARY KEY DEFAULT snowflake.nextval('snowflake.id_seq'),
        owner TEXT NOT NULL, email TEXT UNIQUE,
        balance NUMERIC(14,2) NOT NULL DEFAULT 0,
        lww_bal NUMERIC(14,2) NOT NULL DEFAULT 0,
        updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    ALTER TABLE accounts ALTER COLUMN balance SET (log_old_value=true, delta_apply_function=spock.delta_apply);
" >/dev/null

for i in 2 3; do
    t=0
    until [ "$(qn "pgedge_node${i}" "SELECT count(*) FROM information_schema.tables WHERE table_name='accounts';")" = "1" ]; do
        t=$((t+1)); [ "$t" -ge 20 ] && { echo "[FAIL] Schema DDL did not replicate to node${i}"; exit 1; }
        sleep 1
    done
    echo "[OK] accounts schema + delta_apply replicated to pgedge_node${i}"
done
