FROM ubuntu:22.04
WORKDIR /app
COPY . .
RUN apt-get update && apt-get install -y curl tar ca-certificates
RUN curl -sSL https://panteao.run/install.sh | bash
CMD ["bash", "main.sh"]
