FROM gcc:13
WORKDIR /app
COPY . .
# We assume the SDK tarball is downloaded here or linked properly.
# RUN curl -sSL https://github.com/kkphoenixgx/panteao/releases/download/v1.0/panteao-c.tar.gz | tar xz
# RUN gcc main.c -lpanteao -o main
CMD ["./main"]
