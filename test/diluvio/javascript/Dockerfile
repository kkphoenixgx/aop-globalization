# ============================================================================
# Operação Dilúvio — O Centro de Comando (JavaScript / Node.js)
# ============================================================================
FROM public.ecr.aws/docker/library/node:20-alpine

LABEL maintainer="Panteão BDI Engine Test Suite"
LABEL description="O Centro de Comando — JavaScript/Node.js dashboard test"

WORKDIR /app

COPY sdk ./sdk
COPY client.js .

RUN npm install ./sdk

CMD ["node", "client.js"]
