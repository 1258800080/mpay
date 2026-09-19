FROM webdevops/php-nginx:8.1-alpine

WORKDIR /app

# 安装系统依赖和PHP扩展
RUN apk add --no-cache freetype libpng libjpeg-turbo freetype-dev libpng-dev libjpeg-turbo-dev zip unzip git \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd pdo pdo_mysql bcmath opcache

# 安装composer并配置国内镜像
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer --version=2.2.18 \
    && composer config -g repo.packagist composer https://mirrors.aliyun.com/composer/

# 复制项目代码
COPY . /app

# 安装依赖，忽略平台版本要求，防止版本校验报错
RUN composer install --optimize-autoloader --no-dev --no-interaction --ignore-platform-reqs

# 设置目录权限
RUN chown -R application:application /app/storage /app/bootstrap/cache

# 配置站点和PHP
ENV WEB_DOCUMENT_ROOT=/app/public
ENV PHP_MEMORY_LIMIT=256M

EXPOSE 80
