# ============================================================
# INFHUB Unified Dockerfile
# ============================================================


# ============================================================
# PHP APPLICATION
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

# Create the unprivileged account/group that InspIRCd
# expects at configure time.
RUN groupadd --system inspircd \
    && useradd \
    --system \
    --gid inspircd \
    --home-dir /opt/inspircd \
    --shell /usr/sbin/nologin \
    inspircd

WORKDIR /build

# Copy the complete local InspIRCd source tree.
COPY inspircd/ /build/inspircd/

WORKDIR /build/inspircd

# Configure, compile and install InspIRCd.
#
# --prefix controls where the compiled installation goes.
# --uid / --gid tell InspIRCd which unprivileged account/group
# it should use at runtime.
RUN ./configure \
    --prefix=/opt/inspircd \
    --uid=inspircd \
    --gid=inspircd \
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

# Create runtime user/group.
RUN groupadd --system inspircd \
    && useradd \
    --system \
    --gid inspircd \
    --home-dir /opt/inspircd \
    --shell /usr/sbin/nologin \
    inspircd

# Copy the compiled InspIRCd installation.
COPY --from=inspircd-build /opt/inspircd/ /opt/inspircd/

# Runtime directories.
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