FROM webdevops/php-nginx:8.1-alpine

WORKDIR /app

# 安装系统依赖和PHP扩展
RUN apk add --no-cache freetype libpng libjpeg-turbo freetype-dev libpng-dev libjpeg-turbo-dev zip unzip git \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd pdo pdo_mysql bcmath opcache

# 安装composer并配置阿里云镜像
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer --version=2.2.18 \
    && composer config -g repo.packagist composer https://mirrors.aliyun.com/composer/

# 复制项目代码
COPY . /app

# 安装依赖，忽略平台版本校验
RUN composer install --optimize-autoloader --no-dev --no-interaction --ignore-platform-reqs

# 初始化.env文件 + 生成应用密钥
RUN cp .env.example .env && php artisan key:generate

# 设置目录可写权限
RUN chmod -R 777 /app/storage /app/bootstrap/cache

# 写入Nginx Laravel伪静态配置（解决403 forbidden的核心）
RUN echo 'server { \n\
    listen 80; \n\
    server_name _; \n\
    root /app/public; \n\
    index index.php index.html; \n\
    \n\
    location / { \n\
        try_files $uri $uri/ /index.php?$query_string; \n\
    } \n\
    \n\
    location ~ \.php$ { \n\
        fastcgi_pass 127.0.0.1:9000; \n\
        fastcgi_index index.php; \n\
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name; \n\
        include fastcgi_params; \n\
    } \n\
}' > /etc/nginx/conf.d/default.conf

# 配置PHP内存
ENV PHP_MEMORY_LIMIT=256M

EXPOSE 80
