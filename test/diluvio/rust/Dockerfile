FROM public.ecr.aws/docker/library/rust:1.75
WORKDIR /app
COPY sdk sdk
RUN cargo new client
WORKDIR /app/client
COPY src/main.rs src/main.rs
RUN echo 'panteao-client = { path = "../sdk" }' >> Cargo.toml
RUN cargo build --release
CMD ["./target/release/client"]
