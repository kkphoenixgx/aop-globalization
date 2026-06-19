FROM public.ecr.aws/docker/library/node:20-alpine
WORKDIR /app
COPY client.ts /app/
RUN npm install typescript @types/node
RUN ./node_modules/.bin/tsc client.ts --target es2022 --module commonjs --skipLibCheck --types node
CMD ["node", "client.js"]
