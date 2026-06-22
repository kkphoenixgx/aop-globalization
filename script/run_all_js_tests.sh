#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.."

echo "=============================================="
echo "Running Panteão BDI JS Test Suite"
echo "=============================================="

echo ""
echo "[1/4] Running test_ipc.js..."
START_1=$(date +%s%N)
node script/test_ipc.js
END_1=$(date +%s%N)
ELAPSED_1=$(( (END_1 - START_1) / 1000000 ))

echo ""
echo "[2/4] Running test_counter.js..."
START_2=$(date +%s%N)
node script/test_counter.js
END_2=$(date +%s%N)
ELAPSED_2=$(( (END_2 - START_2) / 1000000 ))

echo ""
echo "[3/4] Running test_all_features.js..."
START_3=$(date +%s%N)
node script/test_all_features.js
END_3=$(date +%s%N)
ELAPSED_3=$(( (END_3 - START_3) / 1000000 ))

echo ""
echo "[4/4] Running test_athena.js..."
START_4=$(date +%s%N)
node script/test_athena.js
END_4=$(date +%s%N)
ELAPSED_4=$(( (END_4 - START_4) / 1000000 ))

# Save to temp file for the master script
mkdir -p build
echo "test_ipc.js:${ELAPSED_1}ms" > build/js_metrics.tmp
echo "test_counter.js:${ELAPSED_2}ms" >> build/js_metrics.tmp
echo "test_all_features.js:${ELAPSED_3}ms" >> build/js_metrics.tmp
echo "test_athena.js:${ELAPSED_4}ms" >> build/js_metrics.tmp

echo ""
echo "=============================================="
echo "All JS tests executed successfully!"
echo "----------------------------------------------"
echo "Performance Metrics (Execution Latency):"
echo "- test_ipc.js: ${ELAPSED_1}ms"
echo "- test_counter.js: ${ELAPSED_2}ms"
echo "- test_all_features.js: ${ELAPSED_3}ms"
echo "- test_athena.js: ${ELAPSED_4}ms"
echo "=============================================="
