FROM node:24-slim AS build
WORKDIR /app
RUN corepack enable || true
COPY . .
RUN npm install --no-audit --no-fund && npm run build

FROM node:24-slim
WORKDIR /app
ENV NODE_ENV=production PORT=3001 HOSTNAME=0.0.0.0
COPY --from=build /app/.next/standalone ./
COPY --from=build /app/.next/static ./.next/static
EXPOSE 3001
CMD ["node", "server.js"]
