#!/bin/bash
set -euo pipefail

DATA_DIR="/var/lib/mysql"

echo ">> Checking database state in $DATA_DIR..."

# 1. Check if initialization has already been done via a sentinel file
if [ ! -f "$DATA_DIR/.initialized" ]; then
    echo ">> ⚠️ Database initialization required..."
    
    # If the mysql directory already exists (partial init), we clean it to start fresh
    if [ -d "$DATA_DIR/mysql" ]; then
        echo ">> 🧹 Cleaning up previous partial initialization..."
        rm -rf "$DATA_DIR"/*
    fi

    # Initialisation de la DB system
    echo ">> 🏗️ Running mariadb-install-db..."
    mariadb-install-db --user=mysql --datadir="$DATA_DIR" --skip-test-db
    
    # Execute initialization scripts
    if [ -d "/docker-entrypoint-initdb.d" ]; then
        echo ">> 📜 Running initialization scripts..."
        mkdir -p /run/mysqld && chown mysql:mysql /run/mysqld || true
        
        SOCKET="/run/mysqld/mysqld_init.sock"
        # Start temporary MariaDB to apply permissions
        mariadbd --user=mysql --datadir="$DATA_DIR" --skip-networking --wsrep-on=OFF --socket="$SOCKET" &
        pid="$!"
        
        # Wait for MariaDB to be ready
        COUNTER=0
        until mariadb --socket="$SOCKET" -u root -e "SELECT 1" >/dev/null 2>&1 || [ $COUNTER -eq 30 ]; do
            echo ">> ⏳ Waiting for MariaDB for init ($COUNTER/30)..."
            sleep 1
            let COUNTER=COUNTER+1
        done
        
        if [ $COUNTER -eq 30 ]; then
            echo ">> ❌ Initialization timeout."
            kill -s TERM "$pid" || true
            exit 1
        fi

        for f in /docker-entrypoint-initdb.d/*; do
            case "$f" in
                *.sql)    echo ">> 🚀 Executing $f..."; mariadb --socket="$SOCKET" -u root < "$f"; echo ;;
                *)        echo ">> ⏭️ Ignored: $f" ;;
            esac
        done
        
        # Set root password from environment variable
        if [ -n "${MARIADB_ROOT_PASSWORD:-}" ]; then
            echo ">> 🔐 Setting root password from environment..."
            mariadb --socket="$SOCKET" -u root -e "
                ALTER USER 'root'@'localhost' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}';
                ALTER USER 'root'@'%' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}';
                FLUSH PRIVILEGES;
            "
        fi
        
        # Shutdown temporary MariaDB
        echo ">> 🛑 Stopping temporary MariaDB..."
        mariadb-admin --socket="$SOCKET" -u root ${MARIADB_ROOT_PASSWORD:+-p"$MARIADB_ROOT_PASSWORD"} shutdown || kill -s TERM "$pid" || true
        wait "$pid" || true
    fi
    
    # Creation of the sentinel file
    touch "$DATA_DIR/.initialized"
    echo ">> ✅ Initialization completed successfully."
else
    echo ">> ✅ Existing and initialized data detected. Normal startup."
fi

# 2. Starting daemon in 'safe' mode
# Note: We let mysqld_safe manage the process.
# Supervisor s'attend à ce que le script ne rende pas la main (foreground),
# mysqld_safe launches a background process by default.
# For Supervisor, it's better to launch mariadbd directly or use exec.

EXTRA_ARGS=""
if [ "${MARIADB_GALERA_BOOTSTRAP:-}" = "1" ]; then
    echo ">> 🌟 Bootstrapping request detected..."
    
    # Force safe_to_bootstrap=1 in grastate.dat if it exists
    if [ -f "$DATA_DIR/grastate.dat" ]; then
        echo ">> 🛠️ Forcing safe_to_bootstrap=1 in grastate.dat"
        sed -i 's/safe_to_bootstrap: 0/safe_to_bootstrap: 1/' "$DATA_DIR/grastate.dat"
    fi

    echo ">> 🔍 Checking if an existing cluster is already reachable (Idempotency Check)..."
    # Note: Using IPs from typical Galera config in this project
    FOUND_OTHER=false
    for peer in 10.6.0.12 10.6.0.13; do
        if timeout 2 bash -c ": >/dev/tcp/$peer/4567" 2>/dev/null; then
            echo ">> 🖇️  Existing cluster node found at $peer. Joining instead of bootstrapping."
            FOUND_OTHER=true
            break
        fi
    done

    if [ "$FOUND_OTHER" = "false" ]; then
        echo ">> 🚀 No existing nodes found. Initializing NEW cluster primary node."
        EXTRA_ARGS="--wsrep-new-cluster"
    else
        echo ">> ⏭️  Existing cluster detected. EXTRA_ARGS left empty for normal JOIN."
    fi
fi

exec mariadbd --datadir="$DATA_DIR" --user=root $EXTRA_ARGS
