# ============================================================
# INFHUB Unified Dockerfile
# ============================================================


# ============================================================
# PHP APPLICATION (Legacy - phased out)
# ============================================================

FROM php:8.4-apache AS php-app

RUN apt-get update && apt-get install -y \
    libzip-dev \
    libcurl4-openssl-dev \
    libonig-dev \
    curl \
    && docker-php-ext-install \
    zip \
    pdo_mysql \
    mysqli \
    curl \
    mbstring \
    && rm -rf /var/lib/apt/lists/*

RUN a2enmod rewrite

COPY src/ /var/www/html/

RUN chown -R www-data:www-data /var/www/html

HEALTHCHECK \
    --interval=30s \
    --timeout=5s \
    --start-period=10s \
    --retries=3 \
    CMD curl -f http://localhost/ || exit 1

EXPOSE 80


# ============================================================
# NEXT.JS APPLICATION
# ============================================================

FROM node:20-alpine AS nextjs

WORKDIR /app

# Install dependencies
COPY package.json package-lock.json* ./
RUN npm ci

# Copy source files
COPY src/app ./src/app
COPY public ./public
COPY next.config.js ./next.config.js
COPY tsconfig.json ./tsconfig.json
COPY next-env.d.ts ./next-env.d.ts

# Build Next.js application
RUN npm run build

# Production runner
FROM node:20-alpine AS nextjs-runtime

WORKDIR /app

ENV NODE_ENV=production

# Copy built application
COPY --from=nextjs /app ./
COPY --from=nextjs /app/node_modules ./node_modules
COPY --from=nextjs /app/public ./public

EXPOSE 3000

HEALTHCHECK \
    --interval=30s \
    --timeout=5s \
    --start-period=10s \
    --retries=3 \
    CMD wget -q -O /dev/null http://localhost:3000/api/health || exit 1

CMD ["npm", "start"]


# ============================================================
# INSPIRCD BUILD
# ============================================================

FROM debian:bookworm-slim AS inspircd-build

RUN apt-get update && apt-get install -y \
    build-essential \
    pkg-config \
    libssl-dev \
    libpcre2-dev \
    libmaxminddb-dev \
    libcurl4-openssl-dev \
    ca-certificates \
    git \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --system inspircd \
    && useradd \
    --system \
    --gid inspircd \
    --home-dir /opt/inspircd \
    --shell /usr/sbin/nologin \
    inspircd

WORKDIR /build

COPY inspircd/inspircd-4.9.0/ /build/inspircd/

WORKDIR /build/inspircd

RUN ./configure \
    --prefix=/opt/inspircd \
    --uid=inspircd \
    --gid=inspircd \
    --disable-auto-extras \
    && make -j"$(nproc)" \
    && make install

# ============================================================
# INSPIRCD RUNTIME
# ============================================================

FROM debian:bookworm-slim AS inspircd

RUN apt-get update && apt-get install -y \
    libssl3 \
    libstdc++6 \
    libgcc-s1 \
    ca-certificates \
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --system inspircd \
    && useradd \
    --system \
    --gid inspircd \
    --home-dir /opt/inspircd \
    --shell /usr/sbin/nologin \
    inspircd

COPY --from=inspircd-build /opt/inspircd/ /opt/inspircd/

RUN mkdir -p \
    /opt/inspircd/run \
    /opt/inspircd/data \
    /opt/inspircd/logs \
    && chown -R inspircd:inspircd /opt/inspircd

ENV INSPIRCD_HOME=/opt/inspircd

WORKDIR /opt/inspircd

EXPOSE 6667 6697

USER inspircd

CMD ["/opt/inspircd/inspircd"]
