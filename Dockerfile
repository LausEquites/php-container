FROM php:8.5-fpm-alpine

LABEL org.opencontainers.image.source="https://github.com/LausEquites/php-container"

#ADD docker/install-php-extensions /usr/local/bin/

# Install PHP modules
# Available modules: https://github.com/mlocati/docker-php-extension-installer
#RUN apk add --update linux-headers # Needed for installing xdebug
#RUN chmod uga+x /usr/local/bin/install-php-extensions && sync && \
#    install-php-extensions opcache apcu mysqlnd pdo_mysql redis bcmath xdebug

RUN apk add --no-cache linux-headers \
    && apk add --no-cache --virtual .build-deps $PHPIZE_DEPS \
    && apk add --no-cache zlib-dev libzip-dev oniguruma-dev pkgconf \
	&& docker-php-ext-install -j$(nproc) bcmath pdo_mysql \
    && pecl install apcu redis xdebug protobuf \
    && docker-php-ext-enable redis xdebug apcu protobuf \
    && apk del .build-deps


# Install packages
RUN apk --no-cache add nginx supervisor curl bash

# Configure nginx
COPY docker/config/nginx.conf /etc/nginx/nginx.conf
RUN chmod a+rw /var/lib/nginx/logs

# Configure PHP-FPM
COPY docker/config/fpm-pool.conf /etc/php7/php-fpm.d/www.conf
COPY docker/config/php.ini /usr/local/etc/php/conf.d/zzz_custom.ini

# Configure supervisord
COPY docker/config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Add composer
ADD --chmod=755 https://getcomposer.org/download/latest-stable/composer.phar /usr/local/bin/composer

# Setup document root
RUN mkdir -p /var/www

# Add application
WORKDIR /var/www

# Build metadata (placed late so changing values only invalidates these layers)
ARG GIT_COMMIT=unknown
ARG BUILD_DATE=unknown

# PHP_VERSION is inherited from the php base image
LABEL org.opencontainers.image.revision="${GIT_COMMIT}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      com.lausequites.main-service.name="php" \
      com.lausequites.main-service.version="${PHP_VERSION}"

RUN printf '{\n  "main_service": {\n    "name": "php",\n    "version": "%s"\n  },\n  "git_commit": "%s",\n  "build_date": "%s"\n}\n' \
        "$PHP_VERSION" "$GIT_COMMIT" "$BUILD_DATE" > /etc/image-info.json

# Expose the port nginx is reachable on
EXPOSE 80

# Let supervisord start nginx & php-fpm
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

# Configure a healthcheck to validate that everything is up&running
#HEALTHCHECK --interval=5s --timeout=10s CMD curl --silent --fail http://127.0.0.1:80/api/devices