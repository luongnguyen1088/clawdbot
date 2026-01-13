FROM node:22-bookworm

# Install Bun (required for build scripts)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

RUN corepack enable

WORKDIR /app

ARG CLAWDBOT_DOCKER_APT_PACKAGES=""
RUN if [ -n "$CLAWDBOT_DOCKER_APT_PACKAGES" ]; then \
      apt-get update && \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $CLAWDBOT_DOCKER_APT_PACKAGES && \
      apt-get clean && \
      rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*; \
    fi

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY patches ./patches
COPY scripts ./scripts

RUN pnpm install --frozen-lockfile

COPY . .
RUN pnpm build
RUN pnpm ui:install
RUN pnpm ui:build
RUN cp -r ui/dist dist/control-ui

ENV NODE_ENV=production
ENV PORT=3000
ENV CLAWDBOT_GATEWAY_CONTROL_UI_BASE_PATH=/ui

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD node -e "const port = process.env.PORT || 3000; fetch('http://localhost:' + port + '/health').then(r => process.exit(r.ok ? 0 : 1))"

# Auto-generate token if missing to prevent startup failure on non-loopback bind
CMD ["/bin/bash", "-c", "export CLAWDBOT_GATEWAY_TOKEN=${CLAWDBOT_GATEWAY_TOKEN:-$(openssl rand -hex 32)}; echo \"Gateway Token: $CLAWDBOT_GATEWAY_TOKEN\"; exec node dist/entry.js gateway --port \"${PORT:-3000}\" --bind lan --allow-unconfigured"]
