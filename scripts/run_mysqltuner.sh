#!/bin/bash
# ===========================================================================
# Script:      run_mysqltuner.sh
# Description: Wrapper to run MySQLTuner against any active topology in
#              multi-db-docker-env. Auto-detects the running environment.
# Author:      Jean-Marie Renouard & Antigravity
# Usage:       bash scripts/run_mysqltuner.sh [--port PORT] [--topology NAME]
# Dependencies: Perl, mysqltuner.pl (local or MYSQLTUNER_PATH env)
# ===========================================================================
set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -f "$PROJECT_ROOT/.env" ]; then
    while IFS='=' read -r key value; do
        [[ -z "$key" || "$key" =~ ^# ]] && continue
        export "$key=$value"
    done < "$PROJECT_ROOT/.env"
fi

DB_PASS="${DB_ROOT_PASSWORD:-rootpass}"
DB_USER="root"
REPORT_DIR="$PROJECT_ROOT/reports"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# MySQLTuner location: env var > sibling directory > download
MYSQLTUNER="${MYSQLTUNER_PATH:-}"
if [ -z "$MYSQLTUNER" ]; then
    # Try sibling directory (common dev layout)
    if [ -f "$PROJECT_ROOT/../MySQLTuner-perl/mysqltuner.pl" ]; then
        MYSQLTUNER="$PROJECT_ROOT/../MySQLTuner-perl/mysqltuner.pl"
    elif [ -f "$PROJECT_ROOT/mysqltuner.pl" ]; then
        MYSQLTUNER="$PROJECT_ROOT/mysqltuner.pl"
    fi
fi

if [ -z "$MYSQLTUNER" ] || [ ! -f "$MYSQLTUNER" ]; then
    echo "❌ mysqltuner.pl not found."
    echo "   Set MYSQLTUNER_PATH or place it in a sibling directory."
    echo "   Example: export MYSQLTUNER_PATH=/path/to/mysqltuner.pl"
    exit 1
fi

# Parse arguments
PORT=""
TOPOLOGY=""
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --port|-p)
            PORT="$2"
            shift 2
            ;;
        --topology|-t)
            TOPOLOGY="$2"
            shift 2
            ;;
        *)
            EXTRA_ARGS+=("$1")
            shift
            ;;
    esac
done

# Auto-detect topology and port
detect_topology() {
    # Check for running topologies
    if docker compose -f "$PROJECT_ROOT/docker-compose-galera.yml" ps --services --filter "status=running" 2>/dev/null | grep -q galera; then
        echo "galera"
        return
    fi
    if docker compose -f "$PROJECT_ROOT/docker-compose-innodb-cluster.yml" ps --services --filter "status=running" 2>/dev/null | grep -q mysql_node; then
        echo "innodb_cluster"
        return
    fi
    if docker compose -f "$PROJECT_ROOT/docker-compose-repli.yml" ps --services --filter "status=running" 2>/dev/null | grep -q mariadb; then
        echo "replication"
        return
    fi
    # Standalone
    if docker compose ps --services --filter "status=running" 2>/dev/null | grep -v traefik | head -1 | grep -q .; then
        echo "standalone"
        return
    fi
    echo "none"
}

get_default_port() {
    local topo=$1
    case "$topo" in
        galera)          echo "3511" ;;
        innodb_cluster)  echo "4411" ;;
        replication)     echo "3411" ;;
        standalone)      echo "3306" ;;
        *)               echo "3306" ;;
    esac
}

get_all_ports() {
    local topo=$1
    case "$topo" in
        galera)          echo "3511 3512 3513" ;;
        innodb_cluster)  echo "4411 4412 4413" ;;
        replication)     echo "3411 3412 3413" ;;
        standalone)      echo "3306" ;;
        *)               echo "3306" ;;
    esac
}

# Detect topology if not specified
if [ -z "$TOPOLOGY" ]; then
    TOPOLOGY=$(detect_topology)
fi

if [ "$TOPOLOGY" = "none" ]; then
    echo "❌ No running database topology detected."
    echo "   Start one with: make up-galera, make innodb-up, make up-repli, or make <db_service>"
    exit 1
fi

echo "======================================================================"
echo "  🔍 MySQLTuner Audit: $TOPOLOGY"
echo "  📅 $(date)"
echo "======================================================================"

mkdir -p "$REPORT_DIR"

# Determine ports to scan
if [ -n "$PORT" ]; then
    PORTS="$PORT"
else
    PORTS=$(get_all_ports "$TOPOLOGY")
fi

NODE_IDX=0
for p in $PORTS; do
    NODE_IDX=$((NODE_IDX + 1))
    echo ""
    echo "--- Node $NODE_IDX (port $p) ---"

    # Check connectivity
    if ! MYSQL_PWD="$DB_PASS" mysqladmin -h 127.0.0.1 -P "$p" -u "$DB_USER" ping >/dev/null 2>&1; then
        echo "⚠️  Port $p is not responding, skipping."
        continue
    fi

    OUTPUT_FILE="$REPORT_DIR/mysqltuner_${TOPOLOGY}_node${NODE_IDX}_${TIMESTAMP}.txt"
    REPORT_FILE="$REPORT_DIR/mysqltuner_${TOPOLOGY}_node${NODE_IDX}_${TIMESTAMP}.html"

    perl "$MYSQLTUNER" \
        --host 127.0.0.1 \
        --port "$p" \
        --user "$DB_USER" \
        --pass "$DB_PASS" \
        --verbose \
        --forcemem 256 \
        --reportfile "$REPORT_FILE" \
        ${EXTRA_ARGS:+"${EXTRA_ARGS[@]}"} \
        > "$OUTPUT_FILE" 2>&1 || true

    echo "  📄 Output: $OUTPUT_FILE"
    echo "  📊 Report: $REPORT_FILE"

    # Quick verdict
    if grep -q "Terminated successfully" "$OUTPUT_FILE" 2>/dev/null; then
        echo "  ✅ MySQLTuner completed successfully"
    else
        echo "  ❌ MySQLTuner did not complete successfully"
    fi
done

echo ""
echo "======================================================================"
echo "  ✅ Audit complete. Reports in: $REPORT_DIR"
echo "======================================================================"
