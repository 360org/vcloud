#!/usr/bin/env bash
# VCloud Enterprise Mobile App - 20 Iteration Resource-Safe Stability Loop Script

set -e

PROJECT_DIR="/media/tanma/DATA/save/mobile/vclients"
FLUTTER_BIN="/home/tanma/flutter/bin/flutter"
TEST_FILE="test/chat_features_integration_test.dart"
TOTAL_ITERATIONS=20

echo "================================================================="
echo "🚀 VCLOUD ENTERPRISE: 20-ITERATION RESOURCE-SAFE STABILITY LOOP"
echo "   Constraint: 1-second cool-down delay between iterations for RAM safety"
echo "================================================================="

cd "$PROJECT_DIR"

PASS_COUNT=0
FAIL_COUNT=0
START_TIME=$(date +%s%N)

for i in $(seq 1 $TOTAL_ITERATIONS); do
  ITER_START=$(date +%s%N)
  echo -n "[*] Iteration $i / $TOTAL_ITERATIONS ... "
  
  if $FLUTTER_BIN test "$TEST_FILE" > /dev/null 2>&1; then
    ITER_END=$(date +%s%N)
    LATENCY_MS=$(( (ITER_END - ITER_START) / 1000000 ))
    PASS_COUNT=$((PASS_COUNT + 1))
    echo "✅ PASS (${LATENCY_MS}ms)"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "❌ FAIL"
  fi

  # Cool-down interval to release Dart VM / OS memory on 8GB RAM systems
  if [ "$i" -lt "$TOTAL_ITERATIONS" ]; then
    sleep 1
  fi
done

END_TIME=$(date +%s%N)
TOTAL_TIME_SEC=$(( (END_TIME - START_TIME) / 1000000000 ))
AVG_LATENCY_MS=$(( ((END_TIME - START_TIME) / 1000000) / TOTAL_ITERATIONS ))

echo "================================================================="
echo "📊 FINAL 20-ITERATION STABILITY REPORT"
echo "================================================================="
echo "• Total Iterations Executed  : $TOTAL_ITERATIONS"
echo "• Successful Pass Count     : $PASS_COUNT ✅"
echo "• Failures / Timeouts        : $FAIL_COUNT ❌"
echo "• Pass Rate                  : $(( (PASS_COUNT * 100) / TOTAL_ITERATIONS ))%"
echo "• Total Execution Time       : ${TOTAL_TIME_SEC}s"
echo "• Average Render Latency     : ${AVG_LATENCY_MS}ms / iteration"
echo "================================================================="

if [ "$FAIL_COUNT" -eq 0 ]; then
  exit 0
else
  exit 1
fi
