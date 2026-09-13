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

# Repair module symlinks that point to the old host filesystem.
RUN find src/modules -type l -exec sh -c \
    'target="$(readlink "$1")"; \
    case "$target" in \
    /home/alexljn5/INFHUB/inf_irc/inspircd/*) \
    relative="${target#/home/alexljn5/INFHUB/inf_irc/inspircd/}"; \
    rm "$1"; \
    ln -s "../../$relative" "$1"; \
    ;; \
    esac' \
    sh {} \;

RUN ./configure \
    --prefix=/opt/inspircd \
    --uid=inspircd \
    --gid=inspircd \
    --disable-auto-extras \
    && ./configure \
    --enable-extras "ssl_openssl sslrehashsignal log_syslog regex_posix" \
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