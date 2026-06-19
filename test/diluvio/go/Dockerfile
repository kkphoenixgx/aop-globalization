# ============================================================================
# Operação Dilúvio — A Tempestade IoT (Go / Golang)
#
# Multi-stage build: compile in golang:1.21-alpine, run from scratch.
# Uses --network=host at runtime to reach the Panteão engine on port 44444.
# ============================================================================

# ---- Build stage ----
FROM public.ecr.aws/docker/library/golang:1.21-alpine AS builder

WORKDIR /build

COPY client.go .

# Static binary — no cgo, no external dependencies
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /tempestade-iot client.go

# ---- Run stage ----
FROM scratch

LABEL maintainer="Panteão BDI Engine Test Suite"
LABEL description="A Tempestade IoT — Go goroutines simulating 100 water-level sensors"

COPY --from=builder /tempestade-iot /tempestade-iot

ENTRYPOINT ["/tempestade-iot"]
