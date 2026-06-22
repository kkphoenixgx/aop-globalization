FROM public.ecr.aws/docker/library/node:20-alpine
WORKDIR /app
COPY sdk sdk
RUN cd sdk && npm install && npm run build
COPY client.ts .
RUN echo '{"name":"test-client","dependencies":{"panteaots":"file:./sdk"},"devDependencies":{"typescript":"^5.0.0","@types/node":"^20.0.0"}}' > package.json
RUN npm install
RUN npx tsc client.ts --target es2022 --module commonjs --moduleResolution node --skipLibCheck --esModuleInterop
CMD ["node", "client.js"]
