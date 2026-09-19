FROM webdevops/php-nginx:8.1-alpine

WORKDIR /app

RUN apk add --no-cache freetype libpng libjpeg-turbo freetype-dev libpng-dev libjpeg-turbo-dev zip unzip git \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd pdo pdo_mysql bcmath opcache

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer --version=2.2.18 \
    && composer config -g repo.packagist composer https://mirrors.aliyun.com/composer/

COPY . /app

RUN composer install --optimize-autoloader --no-dev --no-interaction --ignore-platform-reqs

RUN mkdir -p /app/storage /app/bootstrap/cache && chmod -R 777 /app/storage /app/bootstrap/cache

ENV WEB_DOCUMENT_ROOT=/app/public
ENV PHP_MEMORY_LIMIT=256M

EXPOSE 80
