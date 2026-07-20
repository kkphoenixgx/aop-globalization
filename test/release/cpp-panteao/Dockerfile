FROM ubuntu:22.04

# Prevenir prompts de fuso horário
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y cmake g++ curl tar ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .

# Faz o download do SDK C++ a partir das Releases do GitHub
# ATENÇÃO: Isso só vai funcionar após a pipeline criar a release v1.1.7!
RUN curl -sL https://github.com/kkphoenixgx/aop-globalization/releases/download/v1.1.7/panteao-cpp-1.1.7.tar.gz -o panteao.tar.gz && \
    mkdir panteao-sdk && \
    tar -xzf panteao.tar.gz -C panteao-sdk && \
    rm panteao.tar.gz

# Compilar o código do usuário junto com a biblioteca C++
RUN mkdir build && cd build && cmake .. && make

# Rodar o nosso executável (desabilitamos o buffering do C++ implicitamente pelo código fonte)
CMD ["./build/cpp_teste"]
