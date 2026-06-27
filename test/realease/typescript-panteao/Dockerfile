# Estágio 1: build
FROM node:20-bookworm-slim AS builder
WORKDIR /app

COPY package.json ./

RUN npm install typescript @types/node panteao-ts

COPY tsconfig.json ./
COPY src ./src

RUN npm run build

# Estágio 2: execução
FROM node:20-bookworm-slim AS runner
WORKDIR /app

ENV NODE_ENV=production

COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/package-lock.json ./package-lock.json
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/src/project.jcm ./project.jcm

CMD ["node", "dist/test.js"]