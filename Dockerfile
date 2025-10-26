FROM php:8.4-apache

# Install any extensions you might need, like for databases or whatever your assignment requires
RUN apt-get update && apt-get install -y \
    libzip-dev \
    && docker-php-ext-install zip pdo_mysql

# Copy your PHP files into the container
COPY src/ /var/www/html/

# Set permissions if needed
RUN chown -R www-data:www-data /var/www/html

EXPOSE 80