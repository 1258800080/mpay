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
    php82-redis

WORKDIR /app
COPY . /app

RUN mkdir -p /app/runtime /app/public/install && chmod -R 777 /app/runtime /app/config /app/public

EXPOSE 8787

CMD ["php82", "start.php", "start"]
