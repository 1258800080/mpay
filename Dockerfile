FROM webdevops/php-nginx:8.2-alpine

WORKDIR /app

# 安装系统依赖和PHP扩展（包含Webman必需的pcntl、posix、event）
RUN apk add --no-cache freetype libpng libjpeg-turbo freetype-dev libpng-dev libjpeg-turbo-dev libevent-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd pdo pdo_mysql bcmath opcache pcntl posix \
    && pecl install event && docker-php-ext-enable event

COPY . /app

RUN mkdir -p /app/storage /app/bootstrap/cache && chmod -R 777 /app/storage /app/bootstrap/cache

# Nginx反向代理到Webman默认8787端口
RUN cat > /etc/nginx/nginx.conf << 'EOF'
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    sendfile on;
    keepalive_timeout 65;

    server {
        listen 80 default_server;
        server_name _;

        location / {
            proxy_pass http://127.0.0.1:8787;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
EOF

# 启动脚本：后台运行Webman，前台运行Nginx保持容器存活
RUN echo '#!/bin/sh
php /app/start.php start -d
nginx -g "daemon off;"' > /start.sh && chmod +x /start.sh

ENV PHP_MEMORY_LIMIT=256M

EXPOSE 80

CMD ["/start.sh"]
