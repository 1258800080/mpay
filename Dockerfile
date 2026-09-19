FROM webdevops/php-nginx:8.1-alpine

WORKDIR /app

RUN apk add --no-cache freetype libpng libjpeg-turbo freetype-dev libpng-dev libjpeg-turbo-dev zip unzip \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd pdo pdo_mysql bcmath opcache

COPY . /app

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    && composer install --optimize-autoloader --no-dev

RUN chown -R application:application /app/storage /app/bootstrap/cache

ENV WEB_DOCUMENT_ROOT=/app/public
ENV PHP_MEMORY_LIMIT=256M

EXPOSE 80
