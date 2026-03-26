FROM node:20-alpine AS build

RUN apk add --update libc6-compat python3 make g++
RUN apk add --no-cache build-base cairo-dev pango-dev
RUN apk add --no-cache chromium curl git

RUN npm install -g pnpm

ENV PUPPETEER_SKIP_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
ENV NODE_OPTIONS=--max-old-space-size=8192

WORKDIR /usr/src

COPY . .

RUN pnpm install
RUN pnpm build

# --- Healthcheck Setup (for worker mode) ---
WORKDIR /app/healthcheck
COPY docker/worker/healthcheck/package.json .
RUN npm install --omit=dev
COPY docker/worker/healthcheck/healthcheck.js .

WORKDIR /usr/src

# --- Main server target ---
FROM build AS main

EXPOSE 3000
CMD ["/bin/sh", "-c", "pnpm start"]

# --- Worker target ---
FROM build AS worker

ENV WORKER_PORT=5566
EXPOSE ${WORKER_PORT}
CMD ["/bin/sh", "-c", "node /app/healthcheck/healthcheck.js & sleep 5 && pnpm run start-worker"]
