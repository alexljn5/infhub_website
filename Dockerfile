FROM php:8.4-apache

# Install system dependencies and PHP extensions
RUN apt-get update && apt-get install -y \
    libzip-dev \
    libcurl4-openssl-dev \
    libonig-dev \
    && docker-php-ext-install zip pdo_mysql mysqli curl mbstring \
    && rm -rf /var/lib/apt/lists/*

# Enable Apache mod_rewrite (useful for routing later)
RUN a2enmod rewrite

# Copy source
COPY src/ /var/www/html/

# Permissions
RUN chown -R www-data:www-data /var/www/html

# Healthcheck: verify the web server responds
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

EXPOSE 80