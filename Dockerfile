FROM php:8.2-fpm-alpine

ADD docker/install-php-extensions /usr/local/bin/

# Install PHP modules
# Available modules: https://github.com/mlocati/docker-php-extension-installer
RUN apk add --update linux-headers # Needed for installing xdebug
RUN chmod uga+x /usr/local/bin/install-php-extensions && sync && \
    install-php-extensions opcache apcu mysqlnd pdo_mysql redis bcmath xdebug

# Install packages
RUN apk --no-cache add nginx supervisor curl bash

# Configure nginx
COPY docker/config/nginx.conf /etc/nginx/nginx.conf

# Configure PHP-FPM
COPY docker/config/fpm-pool.conf /etc/php7/php-fpm.d/www.conf
COPY docker/config/php.ini /usr/local/etc/php/conf.d/zzz_custom.ini

# Configure supervisord
COPY docker/config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Add composer
COPY https://getcomposer.org/download/latest-stable/composer.phar /usr/local/bin/composer

# Setup document root
RUN mkdir -p /var/www

# Add application
WORKDIR /var/www

# Expose the port nginx is reachable on
EXPOSE 80

# Let supervisord start nginx & php-fpm
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

# Configure a healthcheck to validate that everything is up&running
#HEALTHCHECK --interval=5s --timeout=10s CMD curl --silent --fail http://127.0.0.1:80/api/devices