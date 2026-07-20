#!/bin/bash

# Script to run both release and development tests

set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$DIR/.." && pwd)"
cd "$ROOT_DIR"

if [ ! -f "gradlew" ]; then
    echo "❌ ERRO: Você não está na raiz do projeto Panteão!"
    echo "Por favor, navegue até a pasta raiz antes de rodar os testes."
    exit 1
fi

echo "***************************************************"
echo "        STARTING DEVELOPMENT TESTS                 "
echo "***************************************************"
"$DIR/test_dev.sh"

echo ""
echo "***************************************************"
echo "        STARTING RELEASE TESTS                     "
echo "***************************************************"
"$DIR/test_release.sh"

echo ""
echo "***************************************************"
echo "        🎉 ALL TEST SUITES PASSED! 🎉               "
echo "***************************************************"
