# =============================================================================
# Operação Dilúvio — O Controlo Físico das Comportas
# Dockerfile for C++ gate controller test
# =============================================================================
FROM public.ecr.aws/docker/library/gcc:12-bookworm AS builder

WORKDIR /build
COPY client.cpp .

RUN g++ -std=c++17 -pthread -O2 -Wall -Wextra -o gate_controller client.cpp

# -----------------------------------------------------------------------------
# Runtime stage — slim Debian image
# -----------------------------------------------------------------------------
FROM public.ecr.aws/docker/library/debian:bookworm-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends libstdc++6 && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/gate_controller /usr/local/bin/gate_controller

CMD ["gate_controller"]
