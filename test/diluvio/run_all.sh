#!/bin/bash
# ============================================================
# OPERAÇÃO DILÚVIO - Runner de Testes Multi-Linguagem V5
# Executa cada linguagem via Docker, mostra progresso limpo,
# salva logs individuais e consolidados, e remove imagens locais,
# containers e cache de build intermediário, preservando imagens base.
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
METRICS_FILE="$SCRIPT_DIR/metrics.log"
PORT=44444
JAR_PATH="$PROJECT_DIR/build/libs/jason-ipc-all.jar"
ENGINE_PID=""

# Setup directories and clean metrics
mkdir -p "$LOG_DIR"
echo "============================================================" > "$METRICS_FILE"
echo "  OPERAÇÃO DILÚVIO - Relatório Final de Métricas" >> "$METRICS_FILE"
echo "  Data: $(date -Iseconds)" >> "$METRICS_FILE"
echo "============================================================" >> "$METRICS_FILE"
echo "" >> "$METRICS_FILE"

# Colors for terminal output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}============================================================${NC}"
echo -e "${CYAN}  OPERAÇÃO DILÚVIO - Iniciando Execução de Testes BDI${NC}"
echo -e "${CYAN}============================================================${NC}"
echo "Logs de cada linguagem salvos em: test/diluvio/logs/"
echo "Relatório consolidado de métricas em: test/diluvio/metrics.log"
echo "------------------------------------------------------------"

start_engine() {
    local LANG_NAME="$1"
    local LOG_FILE="$LOG_DIR/${LANG_NAME}.log"
    echo "[Engine] Iniciando motor BDI na porta $PORT..." >> "$LOG_FILE"
    java -jar "$JAR_PATH" "$SCRIPT_DIR/diluvio.jcm" --port "$PORT" >> "$LOG_FILE" 2>&1 &
    ENGINE_PID=$!
    sleep 2
}

stop_engine() {
    if [ -n "$ENGINE_PID" ] && kill -0 "$ENGINE_PID" 2>/dev/null; then
        kill "$ENGINE_PID" 2>/dev/null || true
        wait "$ENGINE_PID" 2>/dev/null || true
        ENGINE_PID=""
    fi
}

cleanup_docker() {
    # Remove container just in case it is hung
    docker rm -f panteao-test-go panteao-test-python panteao-test-javascript \
              panteao-test-c panteao-test-cpp panteao-test-rust \
              panteao-test-java panteao-test-csharp panteao-test-typescript \
              panteao-test-kotlin panteao-test-scala panteao-test-r \
              panteao-test-swift panteao-test-objc panteao-test-dart \
              panteao-test-php panteao-test-ruby panteao-test-shell >/dev/null 2>&1 || true
              
    # Prune only dangling build cache (do NOT delete pulled base images)
    docker builder prune -f >/dev/null 2>&1 || true
    docker image prune -f >/dev/null 2>&1 || true
}

# Trap to guarantee cleanup on exit, failure or interrupt
exit_handler() {
    stop_engine
    cleanup_docker
}
trap 'exit_handler' EXIT

run_test() {
    local INDEX="$1"
    local TOTAL="$2"
    local LANG_NAME="$3"
    local LANG_DIR="$SCRIPT_DIR/$LANG_NAME"
    local DOCKER_TAG="panteao-test-$LANG_NAME"
    local LOG_FILE="$LOG_DIR/${LANG_NAME}.log"

    # Reset log file
    echo "--- Log de Teste para $LANG_NAME ---" > "$LOG_FILE"
    date -Iseconds >> "$LOG_FILE"

    echo -ne "[${INDEX}/${TOTAL}] ${CYAN}${LANG_NAME}${NC}: Building... "

    if [ ! -f "$LANG_DIR/Dockerfile" ]; then
        echo -e "${YELLOW}[SKIP] (Sem Dockerfile)${NC}"
        echo "Linguagem $LANG_NAME pulada devido à ausência de Dockerfile." >> "$LOG_FILE"
        return
    fi

    # 1. Build image
    local BUILD_START=$(date +%s%N)
    if ! docker build --network=host -t "$DOCKER_TAG" "$LANG_DIR" >> "$LOG_FILE" 2>&1; then
        echo -e "${RED}[FAILED BUILD]${NC} (verifique $LOG_FILE)"
        echo -e "  Result: ${RED}FAILED BUILD${NC}" >> "$METRICS_FILE"
        cleanup_docker
        return 1
    fi
    local BUILD_END=$(date +%s%N)
    local BUILD_MS=$(( (BUILD_END - BUILD_START) / 1000000 ))

    echo -ne "${GREEN}[OK]${NC} (${BUILD_MS}ms) | Running... "

    # 2. Start engine
    start_engine "$LANG_NAME"

    # 3. Run container
    local RUN_START=$(date +%s%N)
    local OUTPUT
    OUTPUT=$(docker run --rm --network=host --name "$DOCKER_TAG" "$DOCKER_TAG" 2>&1)
    local RUN_EXIT=$?
    local RUN_END=$(date +%s%N)
    local RUN_MS=$(( (RUN_END - RUN_START) / 1000000 ))

    echo "$OUTPUT" >> "$LOG_FILE"

    # 4. Stop engine
    stop_engine

    # 5. Check outcome
    local STATUS="${RED}[FAILED]${NC}"
    local PASSED="NO"
    if [ $RUN_EXIT -eq 0 ] && echo "$OUTPUT" | grep -qi "sucesso\|success\|ok\|connected\|completed"; then
        STATUS="${GREEN}[OK]${NC} (${RUN_MS}ms)"
        PASSED="YES"
    fi

    echo -ne "$STATUS | Cleaning... "

    # 6. Delete test image
    docker rmi "$DOCKER_TAG" >> "$LOG_FILE" 2>&1 || true
    
    # 7. Clean up dangling local builds only
    docker builder prune -f >> "$LOG_FILE" 2>&1 || true
    docker image prune -f >> "$LOG_FILE" 2>&1 || true

    echo -e "${GREEN}[OK]${NC}"

    # Write to consolidated metrics file
    echo "Linguagem: $LANG_NAME" >> "$METRICS_FILE"
    echo "  Build Time: ${BUILD_MS}ms" >> "$METRICS_FILE"
    echo "  Execution Time: ${RUN_MS}ms" >> "$METRICS_FILE"
    if [ "$PASSED" = "YES" ]; then
        echo "  Result: PASSED" >> "$METRICS_FILE"
    else
        echo "  Result: FAILED" >> "$METRICS_FILE"
        echo "  Output Summary:" >> "$METRICS_FILE"
        echo "$OUTPUT" | head -10 | sed 's/^/    /' >> "$METRICS_FILE"
    fi
    echo "----------------------------------------" >> "$METRICS_FILE"
}

LANGUAGES=(
    "go"
    "python"
    "javascript"
    "c"
    "cpp"
    "rust"
    "java"
    "csharp"
    "typescript"
    "kotlin"
    "scala"
    "r"
    "swift"
    "objc"
    "dart"
    "php"
    "ruby"
    "shell"
)

TOTAL_LANG=${#LANGUAGES[@]}
FAILED_TESTS=0

for i in "${!LANGUAGES[@]}"; do
    run_test "$((i+1))" "$TOTAL_LANG" "${LANGUAGES[$i]}" || FAILED_TESTS=$((FAILED_TESTS+1))
done

echo ""
echo -e "${CYAN}============================================================${NC}"
echo -e "${CYAN}  OPERAÇÃO DILÚVIO FINALIZADA${NC}"
echo -e "${CYAN}============================================================${NC}"
if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}Todos os testes passaram com sucesso!${NC}"
else
    echo -e "${RED}Total de falhas detectadas: $FAILED_TESTS${NC} (Veja os logs individuais para detalhes)"
fi
echo "Relatório completo em: test/diluvio/metrics.log"
echo -e "${CYAN}============================================================${NC}"
