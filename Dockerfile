FROM webdevops/php-nginx:8.2-alpine

WORKDIR /app

RUN apk add --no-cache freetype libpng libjpeg-turbo freetype-dev libpng-dev libjpeg-turbo-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd pdo pdo_mysql bcmath opcache

COPY . /app

RUN chmod -R 777 /app/storage /app/bootstrap/cache

ENV WEB_DOCUMENT_ROOT=/app/public
ENV PHP_MEMORY_LIMIT=256M

EXPOSE 80
