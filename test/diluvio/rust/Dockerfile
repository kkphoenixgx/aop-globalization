FROM public.ecr.aws/docker/library/rust:1.75-slim-bookworm AS builder
WORKDIR /app
RUN cargo new --bin muralha-telemetria
WORKDIR /app/muralha-telemetria
# Add dependencies directly via cargo CLI
RUN cargo add serde --features derive
RUN cargo add serde_json
COPY client.rs src/main.rs
RUN cargo build --release

FROM public.ecr.aws/docker/library/debian:bookworm-slim
WORKDIR /app
COPY --from=builder /app/muralha-telemetria/target/release/muralha-telemetria .
CMD ["./muralha-telemetria"]
