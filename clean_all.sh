#!/bin/bash

echo "🧹 Limpando o Panteão..."

echo "[1/4] Executando Gradle clean..."
./gradlew clean

echo "[2/4] Removendo lixos de compilação da raiz..."
rm -rf bin/panteao-engine
rm -rf bin/panteao-engine.exe

echo "[3/4] Removendo engines nativas da pasta sdk/engines/..."
rm -f sdk/engines/linux-x64/bin/panteao-engine
rm -f sdk/engines/win32-x64/bin/panteao-engine.exe
rm -f sdk/engines/darwin-arm64/bin/panteao-engine
rm -f sdk/engines/darwin-x64/bin/panteao-engine

echo "[4/5] Limpando diretórios de build dos testes de desenvolvimento..."
find test/development -type d -name "build" -exec rm -rf {} + 2>/dev/null

echo "[5/5] Removendo containers e imagens Docker geradas pelo Panteão..."
# Remove todos os containers com "panteao" no nome
docker ps -a -q --filter "name=panteao" | xargs -r docker rm -f 
# Remove todas as imagens que começam com "panteao"
docker images -q "*panteao*" | xargs -r docker rmi -f
# Prune para matar lixos de build pendentes do Docker
docker builder prune -a -f

echo "✨ Tudo limpo e brilhando!"
