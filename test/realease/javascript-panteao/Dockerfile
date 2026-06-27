FROM node:20-bookworm-slim
WORKDIR /app

COPY . .
RUN npm init -y
RUN sed -i 's/"type": "commonjs"/"type": "module"/' package.json
RUN npm install panteao-js

CMD ["node", "teste.js"]