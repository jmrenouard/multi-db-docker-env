#!/bin/bash
# test_perf_mongo.sh — Performance Benchmark suite for MongoDB ReplicaSet
set -euo pipefail

NODE="${MONGO_NODE1:-mongo1}"
REPORT_DIR="./reports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_MD="${REPORT_DIR}/perf_mongo_${TIMESTAMP}.md"
REPORT_HTML="${REPORT_DIR}/perf_mongo_${TIMESTAMP}.html"

mkdir -p "$REPORT_DIR"

echo_title() { echo -e "\n\033[1;36m>> $1\033[0m"; }
echo_success() { echo -e "\033[0;32m✅ $1\033[0m"; }
echo_error() { echo -e "\033[0;31m❌ $1\033[0m"; }

usage() {
    echo "Usage: $0 [light|standard|read|write] [prepare|run|cleanup]"
    echo ""
    echo "Profiles:"
    echo "  light     : 1,000 documents, 10s run (Quick check)"
    echo "  standard  : 10,000 documents, 30s run"
    echo "  read      : Read-heavy profile (10,000 documents, 30s)"
    echo "  write     : Write-heavy profile (10,000 documents, 30s)"
    exit 1
}

if [ "$#" -ne 2 ]; then usage; fi

PROFILE=$1
ACTION=$2

case $PROFILE in
    light)
        DOC_COUNT=1000
        DURATION=10
        MODE="mixed"
        ;;
    standard)
        DOC_COUNT=10000
        DURATION=30
        MODE="mixed"
        ;;
    read)
        DOC_COUNT=10000
        DURATION=30
        MODE="read"
        ;;
    write)
        DOC_COUNT=10000
        DURATION=30
        MODE="write"
        ;;
    *)
        usage
        ;;
esac

run_mongo_js() {
    local js_code="$1"
    docker exec "$NODE" mongosh --quiet --eval "$js_code"
}

case $ACTION in
    prepare)
        echo_title "Preparing MongoDB Benchmark Dataset ($PROFILE profile, $DOC_COUNT docs)..."
        run_mongo_js "
            db = db.getSiblingDB('bench_mongo');
            db.bench.drop();
            db.bench.createIndex({ idx: 1 });
            var docs = [];
            for (var i = 0; i < $DOC_COUNT; i++) {
                docs.push({ idx: i, data: 'bench_payload_' + i, ts: new Date() });
                if (docs.length >= 1000) {
                    db.bench.insertMany(docs);
                    docs = [];
                }
            }
            if (docs.length > 0) db.bench.insertMany(docs);
            print('Inserted ' + db.bench.countDocuments() + ' benchmark documents.');
        "
        echo_success "Dataset preparation complete."
        ;;
    run)
        echo_title "Running MongoDB Benchmark ($PROFILE profile, mode=$MODE, duration=${DURATION}s)..."
        
        # Ensure collection exists
        COUNT=$(run_mongo_js "db.getSiblingDB('bench_mongo').bench.countDocuments()" 2>/dev/null || echo "0")
        if [ "$COUNT" -eq 0 ]; then
            echo_error "Benchmark dataset empty. Run 'prepare' action first."
            exit 1
        fi

        START_TIME=$(date +%s)
        STATS=$(run_mongo_js "
            db = db.getSiblingDB('bench_mongo');
            var startTime = new Date().getTime();
            var endTime = startTime + ($DURATION * 1000);
            var ops = 0;
            var errors = 0;
            var mode = '$MODE';

            while (new Date().getTime() < endTime) {
                try {
                    if (mode === 'read') {
                        var randIdx = Math.floor(Math.random() * $DOC_COUNT);
                        db.bench.findOne({ idx: randIdx });
                    } else if (mode === 'write') {
                        db.bench.insertOne({ idx: ops, data: 'stream_write', ts: new Date() });
                    } else {
                        var randIdx = Math.floor(Math.random() * $DOC_COUNT);
                        db.bench.findOne({ idx: randIdx });
                        db.bench.updateOne({ idx: randIdx }, { \$set: { ts: new Date() } });
                    }
                    ops++;
                } catch(e) {
                    errors++;
                }
            }
            var elapsedSec = (new Date().getTime() - startTime) / 1000;
            var qps = (ops / elapsedSec).toFixed(2);
            print(ops + ',' + elapsedSec.toFixed(2) + ',' + qps + ',' + errors);
        ")

        IFS=',' read -r TOTAL_OPS ELAPSED_SEC QPS ERROR_COUNT <<< "$STATS"

        cat <<EOF > "$REPORT_MD"
# MongoDB Performance Benchmark Report
**Date:** $(date)
**Profile:** $PROFILE
**Mode:** $MODE
**Duration:** ${DURATION}s

## Benchmark Metrics
- **Total Operations:** $TOTAL_OPS
- **Elapsed Time:** ${ELAPSED_SEC}s
- **Throughput (QPS/OPS):** $QPS ops/sec
- **Error Count:** $ERROR_COUNT
EOF

        cat <<HTMLEOF > "$REPORT_HTML"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>MongoDB Benchmark Report</title>
<style>
body { font-family: system-ui, sans-serif; max-width: 800px; margin: 2rem auto; padding: 0 1rem; background: #0d1117; color: #c9d1d9; }
h1 { color: #58a6ff; border-bottom: 1px solid #30363d; padding-bottom: 0.5rem; }
ul { background: #161b22; padding: 1.5rem; border-radius: 6px; list-style: none; }
li { margin-bottom: 0.5rem; font-size: 1.1rem; }
</style>
</head>
<body>
<h1>🍃 MongoDB Performance Benchmark Report</h1>
<p><strong>Profile:</strong> $PROFILE | <strong>Mode:</strong> $MODE | <strong>Duration:</strong> ${DURATION}s</p>
<ul>
  <li>📊 <strong>Total Operations:</strong> $TOTAL_OPS</li>
  <li>⏱️ <strong>Elapsed Time:</strong> ${ELAPSED_SEC}s</li>
  <li>🚀 <strong>Throughput (QPS/OPS):</strong> <strong>$QPS ops/sec</strong></li>
  <li>⚠️ <strong>Error Count:</strong> $ERROR_COUNT</li>
</ul>
</body>
</html>
HTMLEOF

        echo_success "Benchmark completed!"
        echo "  Total Ops : $TOTAL_OPS"
        echo "  Elapsed   : ${ELAPSED_SEC}s"
        echo "  QPS/OPS   : $QPS ops/sec"
        echo "  Report MD : $REPORT_MD"
        echo "  Report HTML: $REPORT_HTML"
        ;;
    cleanup)
        echo_title "Cleaning up MongoDB Benchmark Dataset..."
        run_mongo_js "db.getSiblingDB('bench_mongo').dropDatabase()"
        echo_success "Cleanup completed."
        ;;
    *)
        usage
        ;;
esac
