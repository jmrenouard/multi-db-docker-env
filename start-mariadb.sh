#!/bin/bash
set -e

DATA_DIR="/var/lib/mysql"

echo ">> Vérification de l'état de la base de données dans $DATA_DIR..."

# 1. Vérifie si l'initialisation a déjà été faite via un fichier sentinelle
if [ ! -f "$DATA_DIR/.initialized" ]; then
    echo ">> ⚠️ Initialisation de la base de données requise..."
    
    # Si le répertoire mysql existe déjà (init partielle), on le nettoie pour repartir propre
    if [ -d "$DATA_DIR/mysql" ]; then
        echo ">> 🧹 Nettoyage d'une initialisation partielle précédente..."
        rm -rf "$DATA_DIR"/*
    fi

    # Initialisation de la DB system
    echo ">> 🏗️ Exécution de mariadb-install-db..."
    mariadb-install-db --user=mysql --datadir="$DATA_DIR" --skip-test-db
    
    # Execute initialization scripts
    if [ -d "/docker-entrypoint-initdb.d" ]; then
        echo ">> 📜 Exécution des scripts d'initialisation..."
        mkdir -p /run/mysqld && chown mysql:mysql /run/mysqld || true
        
        SOCKET="/run/mysqld/mysqld_init.sock"
        # Start temporary MariaDB to apply permissions
        mariadbd --user=mysql --datadir="$DATA_DIR" --skip-networking --wsrep-on=OFF --socket="$SOCKET" &
        pid="$!"
        
        # Wait for MariaDB to be ready
        COUNTER=0
        until mariadb --socket="$SOCKET" -u root -e "SELECT 1" >/dev/null 2>&1 || [ $COUNTER -eq 30 ]; do
            echo ">> ⏳ Attente de MariaDB pour init ($COUNTER/30)..."
            sleep 1
            let COUNTER=COUNTER+1
        done
        
        if [ $COUNTER -eq 30 ]; then
            echo ">> ❌ Timeout initialisation."
            kill -s TERM "$pid" || true
            exit 1
        fi

        for f in /docker-entrypoint-initdb.d/*; do
            case "$f" in
                *.sql)    echo ">> 🚀 Exécution de $f..."; mariadb --socket="$SOCKET" -u root < "$f"; echo ;;
                *)        echo ">> ⏭️ Ignoré: $f" ;;
            esac
        done
        
        # Shutdown temporary MariaDB
        echo ">> 🛑 Arrêt de la MariaDB temporaire..."
        mariadb-admin --socket="$SOCKET" -u root shutdown || kill -s TERM "$pid" || true
        wait "$pid" || true
    fi
    
    # Création du fichier sentinelle
    touch "$DATA_DIR/.initialized"
    echo ">> ✅ Initialisation terminée avec succès."
else
    echo ">> ✅ Données existantes et initialisées détectées. Démarrage normal."
fi

# 2. Démarrage du démon en mode 'safe'
# Note: On laisse mysqld_safe gérer le processus. 
# Supervisor s'attend à ce que le script ne rende pas la main (foreground),
# mais mysqld_safe lance un background process par défaut.
# Pour Supervisor, il vaut mieux lancer mariadbd directement ou utiliser exec.

echo ">> 🚀 Démarrage de MariaDB Safe..."
if [ "$MARIADB_GALERA_BOOTSTRAP" = "1" ]; then
    echo ">> 🌟 Bootstrapping request detected..."
    
    # Force safe_to_bootstrap=1 in grastate.dat if it exists
    if [ -f "$DATA_DIR/grastate.dat" ]; then
        echo ">> 🛠️ Forçage de safe_to_bootstrap=1 dans grastate.dat"
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
