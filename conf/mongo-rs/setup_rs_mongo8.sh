#!/bin/bash
# setup_rs_mongo8.sh
# Initializes a MongoDB 8 ReplicaSet with 3 members (no auth, lab context)
set -euo pipefail

NODES=("mongo8_n1" "mongo8_n2" "mongo8_n3")

echo "=========================================================="
echo "⚙️  MongoDB 8 ReplicaSet Setup"
echo "=========================================================="

WAIT_RETRIES="${WAIT_RETRIES:-60}"
INTERVAL=2

run_mongosh() {
    local node="$1"; shift
    for opts in "--tls --tlsAllowInvalidCertificates --tlsCertificateKeyFile /etc/ssl/mongo/mongodb.pem --quiet" "--tls --tlsAllowInvalidCertificates --quiet" "--quiet"; do
        if docker exec "$node" mongosh $opts "$@" 2>/dev/null; then return 0; fi
    done
    return 1
}

# 1. Wait for all nodes to be ready
echo ""
echo "1. ⏳ Waiting for all MongoDB 8 nodes to be ready (max $((WAIT_RETRIES * INTERVAL))s)..."
for node in "${NODES[@]}"; do
    RETRIES=0
    while ! run_mongosh "$node" --eval "db.runCommand({ping:1})" &>/dev/null; do
        sleep "$INTERVAL"
        RETRIES=$((RETRIES + 1))
        [ "$RETRIES" -ge "$WAIT_RETRIES" ] && { echo "❌ [ERROR] Timeout waiting for $node" >&2; exit 1; }
    done
    echo "   ✅ [OK] $node is ready."
done

# 2. Initiate ReplicaSet
echo ""
echo "2. ⛓️  Initiating ReplicaSet rs0..."
run_mongosh mongo8_n1 --eval "
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
echo "   ✅ [OK] ReplicaSet initiated."

# 3. Wait for primary election
echo ""
echo "3. ⏳ Waiting for primary election (max 60s)..."
TIMEOUT=60
ELAPSED=0
while true; do
    [ "$(run_mongosh mongo8_n1 --eval "rs.isMaster().ismaster" 2>/dev/null || echo false)" = "true" ] && { echo "   ✅ [OK] mongo8_n1 elected as PRIMARY."; break; }
    sleep 2; ELAPSED=$((ELAPSED + 2))
    [ "$ELAPSED" -ge "$TIMEOUT" ] && { echo "❌ [ERROR] Timeout waiting for primary election" >&2; exit 1; }
done

# 4. Wait for secondaries to sync
echo ""
echo "4. ⏳ Waiting for secondaries to sync (10s)..."
sleep 10

# 5. Verify ReplicaSet status
echo ""
echo "5. 📊 Verifying ReplicaSet status..."
run_mongosh mongo8_n1 --eval "
var s = rs.status();
s.members.forEach(function(m) {
    print(m.name + ' | ' + m.stateStr + ' | health=' + m.health);
});
" 2>/dev/null

echo ""
echo "=========================================================="
echo "🏁 MongoDB 8 ReplicaSet Setup Finished"
echo "=========================================================="
