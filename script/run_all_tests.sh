#!/bin/bash
# Exit immediately if any test script fails
set -e

# Reset metrics file
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.."

REPORT_FILE="metrics_report.md"
echo "# Relatório de Métricas de Teste - Panteão BDI" > "$REPORT_FILE"
echo "Data da execução: $(date)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "## 1. Testes de Integração JavaScript (Local)" >> "$REPORT_FILE"
echo "| Script de Teste | Tempo de Execução (ms) |" >> "$REPORT_FILE"
echo "| :--- | :--- |" >> "$REPORT_FILE"

echo ""
echo ">>> [Phase 1] Running Local Node.js/JS Tests..."
./script/run_all_js_tests.sh

# Read JS metrics and write to report
if [ -f build/js_metrics.tmp ]; then
    while IFS= read -r line; do
        NAME=$(echo "$line" | cut -d: -f1)
        TIME=$(echo "$line" | cut -d: -f2)
        echo "| \`$NAME\` | $TIME |" >> "$REPORT_FILE"
    done < build/js_metrics.tmp
    rm -f build/js_metrics.tmp
fi

echo ""
echo ">>> [Phase 2] Running Multi-Language Integration Tests (Diluvio)..."
./test/diluvio/run_all.sh

# Parse Diluvio metrics and write to report
if [ -f test/diluvio/metrics.log ]; then
    echo "" >> "$REPORT_FILE"
    echo "## 2. Testes Multi-Linguagem (Dilúvio - Docker)" >> "$REPORT_FILE"
    echo "| Linguagem | Tempo de Build | Tempo de Execução | Resultado |" >> "$REPORT_FILE"
    echo "| :--- | :--- | :--- | :--- |" >> "$REPORT_FILE"

    CURRENT_LANG=""
    BUILD_TIME=""
    EXEC_TIME=""
    RESULT=""
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^Linguagem:[[:space:]]*(.*) ]]; then
            CURRENT_LANG="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^[[:space:]]*Build[[:space:]]Time:[[:space:]]*(.*) ]]; then
            BUILD_TIME="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^[[:space:]]*Execution[[:space:]]Time:[[:space:]]*(.*) ]]; then
            EXEC_TIME="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^[[:space:]]*Result:[[:space:]]*(.*) ]]; then
            RESULT="${BASH_REMATCH[1]}"
            if [ -n "$CURRENT_LANG" ]; then
                echo "| **$CURRENT_LANG** | $BUILD_TIME | $EXEC_TIME | $RESULT |" >> "$REPORT_FILE"
            fi
            CURRENT_LANG=""
            BUILD_TIME=""
            EXEC_TIME=""
            RESULT=""
        fi
    done < test/diluvio/metrics.log
fi

echo ""
echo "=============================================="
echo "All test suites completed successfully!"
echo "Metrics report generated: $REPORT_FILE"
echo "=============================================="
