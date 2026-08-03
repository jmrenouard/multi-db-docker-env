#!/bin/bash
# setup_rs.sh
# Initializes a MongoDB ReplicaSet with 3 members (no auth, lab context)
set -euo pipefail

NODES=("mongo1" "mongo2" "mongo3")

run_mongosh() {
    local node="$1"
    shift
    local option_sets=(
        "--tls --tlsAllowInvalidCertificates --tlsCertificateKeyFile /etc/ssl/mongo/mongodb.pem --quiet"
        "--tls --tlsAllowInvalidCertificates --quiet"
        "--quiet"
    )
    for opts in "${option_sets[@]}"; do
        if docker exec "$node" mongosh $opts "$@" 2>/dev/null; then
            return 0
        fi
    done
    return 1
}

echo "=========================================================="
echo "⚙️  MongoDB ReplicaSet Setup"
echo "=========================================================="

# 1. Wait for all nodes to be ready
echo ""
echo "1. ⏳ Waiting for all MongoDB nodes to be ready (max 120s)..."
for node in "${NODES[@]}"; do
    TIMEOUT=120
    ELAPSED=0
    while ! run_mongosh "$node" --eval "db.runCommand({ping:1})" &>/dev/null; do
        sleep 2
        ELAPSED=$((ELAPSED + 2))
        if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
            echo "❌ Timeout waiting for $node"
            exit 1
        fi
    done
    echo "   ✅ $node is ready."
done

# 2. Initiate ReplicaSet
echo ""
echo "2. ⛓️  Initiating ReplicaSet rs0..."
run_mongosh mongo1 --eval "
try {
    rs.initiate({
        _id: 'rs0',
        members: [
            { _id: 0, host: 'mongo1:27017', priority: 2 },
            { _id: 1, host: 'mongo2:27017', priority: 1 },
            { _id: 2, host: 'mongo3:27017', priority: 1 }
        ]
    });
    print('ReplicaSet initiated.');
} catch(e) {
    if (e.codeName === 'AlreadyInitialized') {
        print('ReplicaSet already initialized.');
    } else {
        throw e;
    }
}
" 2>/dev/null
echo "   ✅ ReplicaSet initiated."

# 3. Wait for primary election
echo ""
echo "3. ⏳ Waiting for primary election (max 60s)..."
TIMEOUT=60
ELAPSED=0
while true; do
    IS_PRIMARY=$(run_mongosh mongo1 --eval "rs.isMaster().ismaster" 2>/dev/null || echo "false")
    if [ "$IS_PRIMARY" = "true" ]; then
        echo "   ✅ mongo1 elected as PRIMARY."
        break
    fi
    sleep 2
    ELAPSED=$((ELAPSED + 2))
    if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
        echo "❌ Timeout waiting for primary election"
        exit 1
    fi
done

# 4. Wait for secondaries to sync
echo ""
echo "4. ⏳ Waiting for secondaries to sync (10s)..."
sleep 10

# 5. Verify ReplicaSet status
echo ""
echo "5. 📊 Verifying ReplicaSet status..."
run_mongosh mongo1 --eval "
var s = rs.status();
s.members.forEach(function(m) {
    print(m.name + ' | ' + m.stateStr + ' | health=' + m.health);
});
" 2>/dev/null

echo ""
echo "=========================================================="
echo "🏁 MongoDB ReplicaSet Setup Finished"
echo "=========================================================="
