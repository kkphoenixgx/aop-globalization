# ============================================================================
# Operação Dilúvio — O Analisador de Correntes (Scala)
# ============================================================================
FROM public.ecr.aws/docker/library/eclipse-temurin:17-jdk-jammy

LABEL maintainer="Panteão BDI Engine Test Suite"
LABEL description="O Analisador de Correntes — Scala big data soil analysis test"

# Copy pre-downloaded scala-cli from host
COPY scala-cli /usr/local/bin/scala-cli
RUN chmod +x /usr/local/bin/scala-cli && scala-cli version

WORKDIR /app

COPY Client.scala .

# Pre-compile to speed up runtime
RUN scala-cli compile Client.scala

CMD ["scala-cli", "run", "Client.scala"]
