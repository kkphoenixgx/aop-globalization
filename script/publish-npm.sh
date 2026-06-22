#!/bin/bash
# Publica panteao-js e panteao-ts no npm
# Uso: ./script/publish-npm.sh [versão]
# Exemplo: ./script/publish-npm.sh 1.0.1

set -e

VERSION=${1:-""}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/.."

if [ -n "$VERSION" ]; then
    echo "🔖 Atualizando versão para $VERSION..."
    npm version "$VERSION" --no-git-tag-version -prefix "$ROOT/sdk/javascript"
    npm version "$VERSION" --no-git-tag-version -prefix "$ROOT/sdk/typescript"
fi

echo ""
echo "📦 Publicando panteao-js..."
cd "$ROOT/sdk/javascript"
npm publish --access public

echo ""
echo "📦 Buildando panteao-ts..."
cd "$ROOT/sdk/typescript"
npm install
npm run build

echo ""
echo "📦 Publicando panteao-ts..."
npm publish --access public

echo ""
echo "✅ Publicação concluída!"
echo "   panteao-js → https://www.npmjs.com/package/panteao-js"
echo "   panteao-ts → https://www.npmjs.com/package/panteao-ts"
