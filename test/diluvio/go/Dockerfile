# ============================================================================
# Operação Dilúvio — A Tempestade IoT (Go / Golang)
# ============================================================================

# ---- Build stage ----
FROM public.ecr.aws/docker/library/golang:1.21-alpine AS builder

WORKDIR /build

COPY sdk ./sdk
COPY go.mod .
COPY client.go .

# Static binary — no cgo, no external dependencies
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /tempestade-iot client.go

# ---- Run stage ----
FROM scratch

LABEL maintainer="Panteão BDI Engine Test Suite"
LABEL description="A Tempestade IoT — Go goroutines simulating 100 water-level sensors"

COPY --from=builder /tempestade-iot /tempestade-iot

ENTRYPOINT ["/tempestade-iot"]
