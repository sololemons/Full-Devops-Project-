FROM node:18-alpine AS builder
WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY src/ ./src/

RUN npm prune --production

FROM node:18-alpine 

WORKDIR /app
ENV NODE_ENV=production

RUN addgroup -S kijani && adduser -S kijani -G kijani

COPY --chown=kijani:kijani --from=builder /app/node_modules ./node_modules
COPY --chown=kijani:kijani --from=builder /app/src ./src

USER kijani

HEALTHCHECK --interval=30s \
            --timeout=5s \
            --start-period=15s \
            --retries=3 \
  CMD wget -qO- http://localhost:8067/api/health || exit 1

EXPOSE 8067

CMD ["node", "src/index.js"]