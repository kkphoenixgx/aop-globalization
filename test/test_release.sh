#!/bin/bash

# Script to build, test, and clean up Docker containers for all SDKs in test/realease

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/release"
cd "$BASE_DIR" || exit 1

FAILED_SDKS=""

for dir in */ ; do
    lang=$(basename "$dir")
    echo "============================================================"
    echo "🏗️  Building and testing $lang..."
    echo "============================================================"
    
    cd "$lang" || exit 1
    
    # Generate a lowercase image name
    img_name="panteao-test-${lang,,}"
    
    # 1. Build the image
    echo "[1/3] Building Docker image $img_name..."
    if ! docker build -t "$img_name" . ; then
        echo "❌ BUILD FAILED for $lang"
        FAILED_SDKS="$FAILED_SDKS $lang(build)"
        cd ..
        continue
    fi
    
    # 2. Run the container with a timeout and CAPTURE OUTPUT
    echo "[2/3] Running container (Waiting up to 15 seconds)..."
    output=$(timeout 15 docker run --name "${img_name}-run" --rm "$img_name" 2>&1)
    
    echo ">>> Container Output:"
    echo "$output"
    echo "<<< End of Output"
    
    # 3. VERIFY IF TERMINAL SAID [bob] OK
    if echo "$output" | grep -q "\[bob\] OK"; then
        echo "✅ TEST PASSED for $lang (Found '[bob] OK')"
    else
        echo "❌ TEST FAILED for $lang (Did not find '[bob] OK')"
        FAILED_SDKS="$FAILED_SDKS $lang(run)"
    fi
    
    # 4. Clean up the image
    echo "[3/3] Cleaning up image $img_name..."
    docker rmi "$img_name" -f
    
    echo ""
    cd ..
done

# Final cleanup (Aggressive Garbage Collection)
echo "============================================================"
echo "🧹 Running Aggressive Garbage Collection..."
docker image prune -f
docker builder prune -a -f
echo "============================================================"

echo "============================================================"
if [ -z "$FAILED_SDKS" ]; then
    echo "🎉 ALL TESTS PASSED SUCCESSFULLY! PROOF OF WORKING ENGINE!"
    exit 0
else
    echo "💥 THE FOLLOWING SDKS FAILED:$FAILED_SDKS"
    exit 1
fi
