# Build: docker build --tag=organ-controller .

FROM php:7.4-fpm-alpine
ARG TARGETARCH

ADD docker/install-php-extensions /usr/local/bin/

# Install PHP modules
# Available modules: https://github.com/mlocati/docker-php-extension-installer
RUN chmod uga+x /usr/local/bin/install-php-extensions && sync && \
    install-php-extensions shmop opcache apcu

# Install packages
RUN apk --no-cache add nginx supervisor curl bash

# Configure nginx
COPY docker/config/nginx.conf /etc/nginx/nginx.conf

# Configure PHP-FPM
COPY docker/config/fpm-pool.conf /etc/php7/php-fpm.d/www.conf
COPY docker/config/php.ini /etc/php7/conf.d/zzz_custom.ini

# Configure supervisord
COPY docker/config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Make sure files/folders needed by the processes are accessable when they run under the nobody user
RUN chown -R nobody.nobody /run && \
  chown -R nobody.nobody /var/lib/nginx && \
  chown -R nobody.nobody /var/log/nginx

# Setup document root
RUN mkdir -p /var/www

# Make the document root a volume
VOLUME /var/www/html

# Switch to use a non-root user from here on
#USER nobody

# Add application
WORKDIR /var/www

# Expose the port nginx is reachable on
EXPOSE 80

# Let supervisord start nginx & php-fpm
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

# Configure a healthcheck to validate that everything is up&running
#HEALTHCHECK --interval=5s --timeout=10s CMD curl --silent --fail http://127.0.0.1:80/api/devices