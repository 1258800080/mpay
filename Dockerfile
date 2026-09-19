FROM alpine:3.20

RUN apk add --no-cache \
    php82-cli \
    php82-phar \
    php82-pcntl \
    php82-posix \
    php82-pdo \
    php82-pdo_mysql \
    php82-mbstring \
    php82-bcmath \
    php82-zip \
    php82-json \
    php82-tokenizer \
    php82-fileinfo \
    php82-session \
    php82-curl \
    php82-redis \
    composer

WORKDIR /app
COPY . /app

# 阿里云镜像加速安装依赖，忽略平台校验
RUN composer config -g repo.packagist composer https://mirrors.aliyun.com/composer/ \
    && composer install --optimize-autoloader --no-dev --no-interaction --ignore-platform-reqs

RUN mkdir -p /app/runtime /app/public/install && chmod -R 777 /app/runtime /app/config /app/public

EXPOSE 8787

CMD ["php82", "start.php", "start"]
