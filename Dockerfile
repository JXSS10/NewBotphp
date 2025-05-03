# 1. استخدم صورة PHP CLI حديثة وخفيفة كنقطة بداية
FROM php:8.1-cli-alpine AS builder

# تحديث الحزم وتثبيت الأدوات الأساسية وتبعيات PHP
RUN apk update && apk add --no-cache \
    git \
    unzip \
    libzip-dev \
    curl-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    oniguruma-dev \ # <--- فقط اجعل الـ backslash هنا
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd zip curl mbstring sockets bcmath pdo pdo_mysql \
    && apk del curl-dev libzip-dev libpng-dev libjpeg-turbo-dev freetype-dev oniguruma-dev # <--- التعليق هنا لا يسبب مشكلة

# تثبيت Composer (مدير الحزم لـ PHP)
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# تعيين مجلد العمل داخل الحاوية
WORKDIR /app

# نسخ ملفات composer أولاً للاستفادة من التخزين المؤقت لـ Docker
COPY composer.json composer.lock* ./

# تثبيت الاعتمادات (حتى لو كانت فارغة الآن) وتحسين autoloader
RUN composer install --no-interaction --no-dev --optimize-autoloader

# نسخ باقي كود التطبيق
COPY . .

# إنشاء المجلدات ومنح الأذونات (!!! بيانات مؤقتة !!!)
RUN mkdir -p data game spam \
    data/developers data/manger data/admin_user data/mmyaz data/addrd \
    data/dog data/jok data/count data/kickme data/kickmelist \
    && chown -R www-data:www-data /app/data /app/game /app/spam \
    && touch msgs.json game.json \
    && chown www-data:www-data msgs.json game.json

# تعيين المستخدم الذي سيُشغَّل به التطبيق
USER www-data

# الأمر الافتراضي لتشغيل البوت
CMD ["php", "index.php"]
