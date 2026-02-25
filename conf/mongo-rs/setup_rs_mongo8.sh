#!/bin/bash
# setup_rs_mongo8.sh
# Initializes a MongoDB 8 ReplicaSet with 3 members (no auth, lab context)
set -euo pipefail

NODES=("mongo8_n1" "mongo8_n2" "mongo8_n3")

echo "=========================================================="
echo "⚙️  MongoDB 8 ReplicaSet Setup"
echo "=========================================================="

# 1. Wait for all nodes to be ready
echo ""
echo "1. ⏳ Waiting for all MongoDB 8 nodes to be ready (max 120s)..."
for node in "${NODES[@]}"; do
    TIMEOUT=120
    ELAPSED=0
    while ! docker exec "$node" mongosh --quiet --eval "db.runCommand({ping:1})" &>/dev/null; do
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
docker exec mongo8_n1 mongosh --quiet --eval "
try {
    rs.initiate({
        _id: 'rs0',
        members: [
            { _id: 0, host: 'mongo8_n1:27017', priority: 2 },
            { _id: 1, host: 'mongo8_n2:27017', priority: 1 },
            { _id: 2, host: 'mongo8_n3:27017', priority: 1 }
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
    IS_PRIMARY=$(docker exec mongo8_n1 mongosh --quiet --eval "rs.isMaster().ismaster" 2>/dev/null || echo "false")
    if [ "$IS_PRIMARY" = "true" ]; then
        echo "   ✅ mongo8_n1 elected as PRIMARY."
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
docker exec mongo8_n1 mongosh --quiet --eval "
var s = rs.status();
s.members.forEach(function(m) {
    print(m.name + ' | ' + m.stateStr + ' | health=' + m.health);
});
" 2>/dev/null

echo ""
echo "=========================================================="
echo "🏁 MongoDB 8 ReplicaSet Setup Finished"
echo "=========================================================="
