FROM ubuntu:24.04

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y openjdk-21-jre-headless build-essential cmake gcc g++ && rm -rf /var/lib/apt/lists/*

WORKDIR /repo
COPY . .

WORKDIR /app
COPY test/development/ipc /app/

# Build the C++ test
RUN mkdir build && cd build && cmake .. && make

RUN echo '#!/bin/bash\n/repo/build/install/Panteao/bin/Panteao "$@"' > /usr/local/bin/panteao-engine && \
    chmod +x /usr/local/bin/panteao-engine

# Start the java engine in background, wait a bit, then start the C++ test
CMD panteao-engine test_ipc.jcm --port 44444 & sleep 2 && ./build/test_agent
