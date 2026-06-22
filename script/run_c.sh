#!/bin/bash
cd test/diluvio/c
rm -rf sdk
cp -r ../../../sdk/c sdk
docker build --no-cache -t panteao-test-c .
cd ../../..
./bin/panteao-engine test/diluvio/diluvio.jcm --port 44444 > engine_c.log 2>&1 &
ENGINE_PID=$!
sleep 2
docker run --rm --network=host panteao-test-c
echo "DOCKER EXIT: $?"
kill -9 $ENGINE_PID
