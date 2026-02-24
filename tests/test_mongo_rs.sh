#!/bin/bash
# test_mongo_rs.sh
# Functional test suite for MongoDB ReplicaSet (lab context, no auth)
set -euo pipefail

PASS=0
FAIL=0
REPORT_DIR="./reports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_MD="${REPORT_DIR}/test_mongo_rs_${TIMESTAMP}.md"
REPORT_HTML="${REPORT_DIR}/test_mongo_rs_${TIMESTAMP}.html"

mkdir -p "$REPORT_DIR"

write_report() {
    echo "$1" >> "$REPORT_MD"
}

run_mongo() {
    local node="$1"
    shift
    docker exec "$node" mongosh --quiet "$@"
}

write_report "# MongoDB ReplicaSet Test Report"
write_report "**Date:** $(date)"
write_report "**Environment:** MongoDB 7.0 ReplicaSet (3 nodes + HAProxy)"
write_report ""

echo "=========================================================="
echo "🚀 MongoDB ReplicaSet Test Suite"
echo "=========================================================="

# ─── TEST 1: Node Status ───
echo ""
echo "1. 📊 Checking MongoDB Node Status..."
write_report "## 1. Node Status"

for node in mongo1 mongo2 mongo3; do
    VERSION=$(run_mongo "$node" --eval "db.version()" 2>/dev/null || echo "FAILED")
    if [ "$VERSION" != "FAILED" ]; then
        echo "✅ $node: UP (MongoDB $VERSION)"
        write_report "- ✅ $node: UP (MongoDB $VERSION)"
        PASS=$((PASS + 1))
    else
        echo "❌ $node: DOWN"
        write_report "- ❌ $node: DOWN"
        FAIL=$((FAIL + 1))
    fi
done

# ─── TEST 2: ReplicaSet Members ───
echo ""
echo "2. ⛓️ ReplicaSet Status..."
write_report "## 2. ReplicaSet Status"

RS_MEMBERS=$(run_mongo mongo1 --eval "rs.status().members.length" 2>/dev/null || echo "0")
if [ "$RS_MEMBERS" = "3" ]; then
    echo "✅ ReplicaSet: $RS_MEMBERS members active"
    write_report "- ✅ ReplicaSet: $RS_MEMBERS members active"
    PASS=$((PASS + 1))
else
    echo "❌ ReplicaSet: expected 3 members, got $RS_MEMBERS"
    write_report "- ❌ ReplicaSet: expected 3, got $RS_MEMBERS"
    FAIL=$((FAIL + 1))
fi

# Display RS status
run_mongo mongo1 --eval "
var s = rs.status();
s.members.forEach(function(m) {
    print(m.name + '\t' + m.stateStr);
});
" 2>/dev/null || true

# ─── TEST 3: HAProxy Connectivity ───
echo ""
echo "3. 🔌 Testing HAProxy Connectivity..."
write_report "## 3. HAProxy"

echo ">> Testing port 27100 (RW)..."
if docker exec mongo1 mongosh --host haproxy_mongo --port 27100 --quiet --eval "db.runCommand({ping:1})" &>/dev/null; then
    echo "✅ HAProxy (27100) connected"
    write_report "- ✅ HAProxy (27100): Connected"
    PASS=$((PASS + 1))
else
    echo "❌ HAProxy (27100) FAILED"
    write_report "- ❌ HAProxy (27100): FAILED"
    FAIL=$((FAIL + 1))
fi

# ─── TEST 4: Write Replication ───
echo ""
echo "4. 📝 Write Replication Test..."
write_report "## 4. Write Replication"

run_mongo mongo1 --eval "
db = db.getSiblingDB('testdb');
db.repltest.drop();
db.repltest.insertOne({key: 'test', value: 'replication_check', ts: new Date()});
" 2>/dev/null

sleep 3

for node in mongo2 mongo3; do
    COUNT=$(run_mongo "$node" --eval "
        db.getMongo().setReadPref('secondaryPreferred');
        db.getSiblingDB('testdb').repltest.countDocuments({key: 'test'});
    " 2>/dev/null || echo "0")
    if [ "$COUNT" = "1" ]; then
        echo "✅ Replication to $node working (Count: $COUNT)"
        write_report "- ✅ $node: replicated ($COUNT doc)"
        PASS=$((PASS + 1))
    else
        echo "❌ Replication to $node FAILED (Count: $COUNT)"
        write_report "- ❌ $node: FAILED ($COUNT)"
        FAIL=$((FAIL + 1))
    fi
done

# ─── TEST 5: Write Isolation ───
echo ""
echo "5. 🛡️ Write Isolation Test (Secondaries)..."
write_report "## 5. Write Isolation"

for node in mongo2 mongo3; do
    RESULT=$(run_mongo "$node" --eval "
        try {
            db.getSiblingDB('testdb').writetest.insertOne({test: 1});
            'ALLOWED';
        } catch(e) {
            'REJECTED';
        }
    " 2>/dev/null || echo "REJECTED")
    if echo "$RESULT" | grep -q "REJECTED"; then
        echo "✅ $node correctly rejected write"
        write_report "- ✅ $node: write rejected"
        PASS=$((PASS + 1))
    else
        echo "⚠️  $node accepted write (may be transitioning)"
        write_report "- ⚠️  $node: write accepted"
        FAIL=$((FAIL + 1))
    fi
done

# ─── TEST 6: CRUD Operations ───
echo ""
echo "6. 🏗️ CRUD Operations Test..."
write_report "## 6. CRUD Operations"

CRUD_RESULT=$(docker exec mongo1 mongosh --quiet --eval '
db = db.getSiblingDB("testdb");
db.crud.drop();
db.crud.insertMany([{a:1},{a:2},{a:3}]);
var c = db.crud.countDocuments();
db.crud.updateOne({a:1}, {$set: {a:10}});
var u = db.crud.findOne({a:10});
db.crud.deleteOne({a:2});
var d = db.crud.countDocuments();
print(c + "," + (u ? "ok" : "fail") + "," + d);
' 2>/dev/null || echo "0,fail,0")

if echo "$CRUD_RESULT" | grep -q "3,ok,2"; then
    echo "✅ CRUD operations successful (insert=3, update=ok, delete→2)"
    write_report "- ✅ CRUD: insert=3, update=ok, after delete=2"
    PASS=$((PASS + 1))
else
    echo "❌ CRUD operations failed: $CRUD_RESULT"
    write_report "- ❌ CRUD: $CRUD_RESULT"
    FAIL=$((FAIL + 1))
fi

# ─── TEST 7: Version Consistency ───
echo ""
echo "7. 🔢 MongoDB Version Consistency..."
write_report "## 7. Version Consistency"

V1=$(run_mongo mongo1 --eval "db.version()" 2>/dev/null)
V2=$(run_mongo mongo2 --eval "db.version()" 2>/dev/null)
V3=$(run_mongo mongo3 --eval "db.version()" 2>/dev/null)

if [ "$V1" = "$V2" ] && [ "$V2" = "$V3" ]; then
    echo "✅ All nodes running MongoDB $V1"
    write_report "- ✅ All nodes: MongoDB $V1"
    PASS=$((PASS + 1))
else
    echo "❌ Version mismatch: $V1 / $V2 / $V3"
    write_report "- ❌ Mismatch: $V1 / $V2 / $V3"
    FAIL=$((FAIL + 1))
fi

# ─── TEST 8: RS Config Consistency ───
echo ""
echo "8. ⚙️ ReplicaSet Config..."
write_report "## 8. RS Config"

RS_NAME=$(run_mongo mongo1 --eval "rs.conf()._id" 2>/dev/null || echo "NONE")
RS_SIZE=$(run_mongo mongo1 --eval "rs.conf().members.length" 2>/dev/null || echo "0")

if [ "$RS_NAME" = "rs0" ] && [ "$RS_SIZE" = "3" ]; then
    echo "✅ RS config: name=$RS_NAME, members=$RS_SIZE"
    write_report "- ✅ RS: name=$RS_NAME, members=$RS_SIZE"
    PASS=$((PASS + 1))
else
    echo "❌ RS config: name=$RS_NAME, members=$RS_SIZE"
    write_report "- ❌ RS: name=$RS_NAME, members=$RS_SIZE"
    FAIL=$((FAIL + 1))
fi

# ─── SUMMARY ───
TOTAL=$((PASS + FAIL))
echo ""
write_report ""
write_report "## Summary"
write_report "- **Passed:** $PASS / $TOTAL"
write_report "- **Failed:** $FAIL / $TOTAL"

# Generate HTML report
cat > "$REPORT_HTML" << HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>MongoDB RS Test Report</title>
<style>
body { font-family: system-ui, sans-serif; max-width: 900px; margin: 2rem auto; padding: 0 1rem; background: #0d1117; color: #c9d1d9; }
h1 { color: #58a6ff; border-bottom: 1px solid #30363d; padding-bottom: 0.5rem; }
h2 { color: #79c0ff; }
pre { background: #161b22; padding: 1rem; border-radius: 6px; overflow-x: auto; }
</style>
</head>
<body>
$(sed 's/^# /\n<h1>/;s/^## /\n<h2>/;s/^- /<li>/;s/✅/\&#9989;/g;s/❌/\&#10060;/g;s/⚠️/\&#9888;/g' "$REPORT_MD")
</body>
</html>
HTMLEOF

echo "=========================================================="
echo "🏁 MongoDB ReplicaSet Test Suite Finished."
echo "   Passed: $PASS | Failed: $FAIL"
echo "Markdown Report: $REPORT_MD"
echo "HTML Report: $REPORT_HTML"
echo "=========================================================="

[ "$FAIL" -eq 0 ] || exit 1
