# ---------- build ----------
FROM node:20-bookworm AS build

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-setuptools python3-distutils \
    make g++ clang git pkg-config libc6-dev libstdc++-12-dev \
    cmake ninja-build jq \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Yarn Berry files
COPY package.json yarn.lock .yarnrc.yml ./
COPY .yarn ./.yarn

# Source
COPY packages ./packages
COPY app-config*.yaml ./

# (keep if you need it for isolated-vm)
RUN jq '(.resolutions //= {}) | .resolutions["isolated-vm"]="^5.0.4"' package.json > /tmp/package.json \
 && mv /tmp/package.json package.json

RUN corepack enable && yarn install

# This creates skeleton.tar.gz + bundle.tar.gz
RUN yarn --cwd packages/backend build

RUN echo "=== backend dist after build ===" && ls -la packages/backend/dist

# Create the runnable workspace from the tarballs
RUN mkdir -p /app/dist-workspace \
 && tar -xzf packages/backend/dist/skeleton.tar.gz -C /app/dist-workspace \
 && tar -xzf packages/backend/dist/bundle.tar.gz -C /app/dist-workspace

# Install production deps inside the extracted workspace
WORKDIR /app/dist-workspace
RUN corepack enable \
 && yarn install \
 && yarn workspaces focus backend --production

RUN ls -la packages/backend/dist \
 && (test -f packages/backend/dist/index.cjs.js || test -f packages/backend/dist/index.cjs || test -f packages/backend/dist/index.js)

# Sanity check: the bundled backend entry should exist now
RUN ls -la packages/backend/dist \
 && (test -f packages/backend/dist/index.cjs.js || test -f packages/backend/dist/index.cjs || test -f packages/backend/dist/index.js)


# ---------- runtime ----------
FROM node:20-bookworm-slim AS runtime
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv \
  && python3 -m venv /opt/techdocs-venv \
  && /opt/techdocs-venv/bin/pip install --no-cache-dir --upgrade pip mkdocs-techdocs-core \
  && ln -s /opt/techdocs-venv/bin/mkdocs /usr/local/bin/mkdocs \
  && rm -rf /var/lib/apt/lists/*
WORKDIR /app
ENV NODE_ENV=production
EXPOSE 7007

# Copy the fully prepared dist workspace
COPY --from=build /app/dist-workspace/ ./
COPY --from=build /app/app-config*.yaml ./

# Run bundled backend
CMD ["node","packages/backend/dist/index.cjs.js","--config","app-config.yaml"]
