FROM node:20-bookworm-slim
WORKDIR /app

COPY package.json ./package.json
RUN npm install panteao-js

COPY teste.js ./teste.js
COPY teste.jcm ./teste.jcm

CMD ["node", "teste.js"]
