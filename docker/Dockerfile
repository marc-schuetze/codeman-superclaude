# syntax=docker/dockerfile:1
#
# codeman-superclaude — Codeman with the superclaude session-discovery patch
# baked in. Builder clones a pinned upstream commit, applies patches/, builds.
# Runtime is a slim node image with tmux + git so the orchestrator can drive
# the host's tmux server through a bind-mounted socket.

ARG NODE_VERSION=20-bookworm-slim
ARG CODEMAN_REPO=https://github.com/Ark0N/Codeman.git
ARG CODEMAN_COMMIT=e8a809ea80371e8bde4536cca3195f201f45b9fc

# ---- builder ----------------------------------------------------------------
FROM node:${NODE_VERSION} AS builder

RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates \
 && rm -rf /var/lib/apt/lists/*

ARG CODEMAN_REPO
ARG CODEMAN_COMMIT
WORKDIR /build
RUN git init -q . \
 && git remote add origin "${CODEMAN_REPO}" \
 && git fetch --depth 1 origin "${CODEMAN_COMMIT}" \
 && git checkout -q FETCH_HEAD

COPY patches/ /tmp/patches/
RUN for p in /tmp/patches/*.patch; do \
        echo "applying $p"; \
        git -c user.email=build@local -c user.name=build am --keep-cr "$p"; \
    done

RUN npm ci --no-audit --no-fund \
 && npm run build

# ---- runtime ----------------------------------------------------------------
FROM node:${NODE_VERSION} AS runtime

RUN apt-get update \
 && apt-get install -y --no-install-recommends tmux git ca-certificates \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /build/dist        ./dist
COPY --from=builder /build/node_modules ./node_modules
COPY --from=builder /build/package.json ./

EXPOSE 3030
ENV NODE_ENV=production
CMD ["node", "dist/index.js", "web", "--port", "3030"]
