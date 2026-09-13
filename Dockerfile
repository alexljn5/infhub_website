# ============================================================
# INFHUB Unified Dockerfile
#
# Build targets:
#   php-app  -> Apache + PHP website
#   inspircd -> InspIRCd IRC server
#
# docker-compose.yml selects the appropriate target.
# ============================================================


# ============================================================
# PHP / APACHE WEBSITE
# ============================================================

FROM php:8.4-apache AS php-app

# Install system dependencies and PHP extensions
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

# Enable Apache mod_rewrite
RUN a2enmod rewrite

# Copy website source
COPY src/ /var/www/html/

# Permissions
RUN chown -R www-data:www-data /var/www/html

# Healthcheck
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

WORKDIR /build

# Copy the existing InspIRCd source tree
COPY inspircd/ /build/inspircd/

WORKDIR /build/inspircd

# Build InspIRCd
RUN ./configure \
    --prefix=/opt/inspircd \
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

# Dedicated user
RUN useradd \
    --system \
    --home /opt/inspircd \
    --shell /usr/sbin/nologin \
    inspircd \
    && mkdir -p \
    /opt/inspircd \
    /var/lib/inspircd \
    /var/log/inspircd \
    && chown -R inspircd:inspircd \
    /opt/inspircd \
    /var/lib/inspircd \
    /var/log/inspircd

# Copy compiled InspIRCd
COPY --from=inspircd-build /opt/inspircd/ /opt/inspircd/

# Runtime directories
RUN mkdir -p \
    /opt/inspircd/run \
    /opt/inspircd/data \
    /opt/inspircd/logs \
    && chown -R inspircd:inspircd /opt/inspircd

ENV INSPIRCD_HOME=/opt/inspircd

WORKDIR /opt/inspircd

EXPOSE 6667 6697

USER inspircd

# InspIRCd normally uses the executable in the installation root.
CMD ["/opt/inspircd/inspircd"]