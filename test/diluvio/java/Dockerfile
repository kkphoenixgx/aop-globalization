# O Desbloqueio de Fundos de Emergência — Java
# Legacy banking system simulation for emergency fund liberation
#
# Build:  docker build -t diluvio-java .
# Run:    docker run --rm --network=host diluvio-java

FROM public.ecr.aws/docker/library/eclipse-temurin:17-jdk-jammy

LABEL maintainer="Panteão BDI Engine"
LABEL description="Operação Dilúvio — O Desbloqueio de Fundos de Emergência (Java)"

WORKDIR /app

# Copy source and compile
COPY Client.java .
RUN javac Client.java

# Run the test client
CMD ["java", "-cp", ".", "Client"]
