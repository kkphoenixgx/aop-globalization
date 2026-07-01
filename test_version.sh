#!/bin/bash
BASE_VERSION="1.1"
git fetch --tags 2>/dev/null
LAST_PATCH=$(git tag -l "v${BASE_VERSION}.*" | sed "s/v${BASE_VERSION}.//" | sort -n | tail -n1)
[ -z "$LAST_PATCH" ] && NEXT_PATCH=0 || NEXT_PATCH=$((LAST_PATCH + 1))

NPM_VER=$(npm view panteao-js version 2>/dev/null || echo "0.0.0")
PYPI_VER=$(curl -s https://pypi.org/pypi/panteao-py/json | jq -r '.info.version' 2>/dev/null || echo "0.0.0")
NUGET_VER=$(curl -s "https://api.nuget.org/v3-flatcontainer/panteao/index.json" | jq -r '.versions[-1]' 2>/dev/null || echo "0.0.0")
DART_VER=$(curl -s https://pub.dev/api/packages/panteao | jq -r '.latest.version' 2>/dev/null || echo "0.0.0")
ENGINE_VER=$(npm view panteao-engine-linux-x64 version 2>/dev/null || echo "0.0.0")

echo "GIT NEXT: $NEXT_PATCH"
echo "NPM: $NPM_VER"
echo "PYPI: $PYPI_VER"
echo "NUGET: $NUGET_VER"
echo "DART: $DART_VER"
echo "ENGINE: $ENGINE_VER"

MAX_PATCH=$NEXT_PATCH
for VER in $NPM_VER $PYPI_VER $NUGET_VER $DART_VER $ENGINE_VER; do
  PATCH=$(echo $VER | awk -F. '{print $3}')
  [ -z "$PATCH" ] || [ "$PATCH" == "null" ] && PATCH=0
  if [ "$PATCH" -ge "$MAX_PATCH" ]; then
    MAX_PATCH=$((PATCH + 1))
  fi
done

echo "FINAL NEXT PATCH: $MAX_PATCH"
echo "FINAL VERSION: ${BASE_VERSION}.${MAX_PATCH}"
