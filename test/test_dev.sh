#!/bin/bash

# Exit on any error
set -e

# Always run from the repository root
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ ! -f "gradlew" ] || [ ! -d "test/development" ]; then
    echo "❌ ERRO: Você não está na raiz do projeto Panteão!"
    echo "Por favor, navegue até a pasta raiz antes de rodar os testes."
    exit 1
fi


echo "==========================================="
echo "   Compiling Panteão Java Engine (Gradle)  "
echo "==========================================="
./gradlew installDist

echo ""
echo "==========================================="
echo "   Running all C++ Development Tests       "
echo "==========================================="

TEST_DIRS=("all_features" "counter" "ipc")

for test_name in "${TEST_DIRS[@]}"; do
    echo ""
    echo "-------------------------------------------"
    echo "   Testing: $test_name"
    echo "-------------------------------------------"
    
    IMAGE_NAME="panteao-dev-cpp-$test_name"
    DOCKERFILE_PATH="test/development/$test_name/Dockerfile"

    # Build the Docker image (must be run from root context '.')
    echo "[BUILDING $IMAGE_NAME]"
    docker build -t "$IMAGE_NAME" -f "$DOCKERFILE_PATH" .
    
    # Run the Docker image
    echo "[RUNNING $IMAGE_NAME]"
    docker run --rm "$IMAGE_NAME"
    
    # Clean up the image immediately after running to save space
    echo "[CLEANUP] Removing image $IMAGE_NAME..."
    docker rmi -f "$IMAGE_NAME"
    
    echo "[SUCCESS] $test_name passed!"
done

echo ""
echo "==========================================="
echo "   Running Aggressive Garbage Collection   "
echo "==========================================="
echo "Wiping dangling images, build caches, and temporary data..."
docker image prune -f
docker builder prune -a -f
echo "[CLEANUP] Workspace is spotless."

echo ""
echo "==========================================="
echo "   All tests completed successfully!       "
echo "==========================================="
