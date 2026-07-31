#!/bin/bash
# tests/test_failover.sh
# Automated HA Failover & Resilience Test Suite across Cluster Topologies

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
    source "$SCRIPT_DIR/lib/common.sh"
else
    PASS=0
    FAIL=0
    assert_pass() { PASS=$((PASS + 1)); echo "✅ $1: $2"; }
    assert_fail() { FAIL=$((FAIL + 1)); echo "❌ $1: $2"; }
    print_summary() { echo "Passed: $PASS | Failed: $FAIL"; [ "$FAIL" -eq 0 ]; }
    init_report() { :; }
fi

init_report "test_failover" "Automated HA Failover Test Report"

TARGET_CLUSTER="${1:-all}"

echo "=========================================================="
echo "⚡ Automated HA Failover Test Suite Target: $TARGET_CLUSTER"
echo "=========================================================="

test_failover_galera() {
    echo ""
    echo "1. 🔄 Galera Cluster Failover Test..."
    if ! docker ps --format '{{.Names}}' | grep -q "mariadb-g1"; then
        echo "⏭️ Skipping Galera failover (mariadb-g1 not running)"
        return 0
    fi

    echo ">> Stopping mariadb-g1..."
    docker stop mariadb-g1 >/dev/null 2>&1
    sleep 5

    # Check Node 2 status
    W_SIZE=$(MYSQL_PWD="${DB_ROOT_PASSWORD:-rootpass}" mariadb -h 127.0.0.1 -P 3512 -uroot -sN -e "SHOW GLOBAL STATUS LIKE 'wsrep_cluster_size';" 2>/dev/null | awk '{print $2}' || echo "0")
    if [ "$W_SIZE" = "2" ]; then
        assert_pass "Galera Failover" "Cluster size reduced to 2 active nodes on node2"
    else
        assert_fail "Galera Failover" "Expected cluster size 2, got $W_SIZE"
    fi

    echo ">> Restarting mariadb-g1..."
    docker start mariadb-g1 >/dev/null 2>&1
    sleep 10
}

test_failover_patroni() {
    echo ""
    echo "2. 🔄 Patroni Cluster Failover Test..."
    if ! docker ps --format '{{.Names}}' | grep -q "^node1$"; then
        echo "⏭️ Skipping Patroni failover (node1 not running)"
        return 0
    fi

    LEADER=$(docker exec node1 patronictl -c /etc/patroni.yml list 2>/dev/null | grep "Leader" | awk '{print $2}' || echo "")
    if [ -n "$LEADER" ]; then
        echo ">> Stopping Patroni Leader ($LEADER)..."
        docker stop "$LEADER" >/dev/null 2>&1
        sleep 10

        NEW_LEADER=$(docker exec node2 patronictl -c /etc/patroni.yml list 2>/dev/null | grep "Leader" | awk '{print $2}' || echo "")
        if [ -n "$NEW_LEADER" ] && [ "$NEW_LEADER" != "$LEADER" ]; then
            assert_pass "Patroni Failover" "New Leader elected: $NEW_LEADER"
        else
            assert_fail "Patroni Failover" "Failover failed, new leader: $NEW_LEADER"
        fi

        echo ">> Restarting $LEADER..."
        docker start "$LEADER" >/dev/null 2>&1
        sleep 5
    fi
}

test_failover_mongo() {
    echo ""
    echo "3. 🔄 MongoDB ReplicaSet Failover Test..."
    if ! docker ps --format '{{.Names}}' | grep -q "^mongo1$"; then
        echo "⏭️ Skipping MongoDB failover (mongo1 not running)"
        return 0
    fi

    echo ">> Stopping mongo1 (Primary)..."
    docker stop mongo1 >/dev/null 2>&1
    sleep 10

    NEW_PRIMARY=$(docker exec mongo2 mongosh --tls --tlsAllowInvalidCertificates --quiet --eval "rs.isMaster().primary" 2>/dev/null || docker exec mongo2 mongosh --quiet --eval "rs.isMaster().primary" 2>/dev/null || echo "")
    if [ -n "$NEW_PRIMARY" ] && [ "$NEW_PRIMARY" != "mongo1:27017" ]; then
        assert_pass "MongoDB Failover" "New Primary elected: $NEW_PRIMARY"
    else
        assert_fail "MongoDB Failover" "Primary election failed: $NEW_PRIMARY"
    fi

    echo ">> Restarting mongo1..."
    docker start mongo1 >/dev/null 2>&1
    sleep 5
}

case "$TARGET_CLUSTER" in
    galera)  test_failover_galera ;;
    patroni) test_failover_patroni ;;
    mongo)   test_failover_mongo ;;
    all)
        test_failover_galera
        test_failover_patroni
        test_failover_mongo
        ;;
esac

print_summary
