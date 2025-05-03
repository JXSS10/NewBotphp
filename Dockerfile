# 1. استخدم صورة PHP CLI حديثة وخفيفة كنقطة بداية
FROM php:8.1-cli-alpine AS builder

# تحديث وتثبيت الأدوات الأساسية، التبعيات اللازمة للتثبيت (dev)، والتبعيات اللازمة للتشغيل
RUN apk update && apk add --no-cache \
    git \
    unzip \
    # مكتبات التشغيل المطلوبة للامتدادات التي سنثبتها
    libpng \
    libjpeg-turbo \
    freetype \
    libzip \
    # مكتبات التطوير (للتثبيت فقط)
    libzip-dev \
    curl-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    oniguruma-dev \
    # إعداد وتثبيت الامتدادات بما فيها gd و zip
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd zip curl mbstring \
    # حذف حزم التطوير فقط، والإبقاء على مكتبات التشغيل
    && apk del --purge \
        libzip-dev \
        curl-dev \
        libpng-dev \
        libjpeg-turbo-dev \
        freetype-dev \
        oniguruma-dev

# تثبيت Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# تعيين مجلد العمل
WORKDIR /app

# نسخ ملفات composer
COPY composer.json composer.lock* ./

# تثبيت الاعتمادات
RUN composer install --no-interaction --no-dev --optimize-autoloader

# نسخ باقي كود التطبيق
COPY . .

# ------- [ تحذير مهم جداً - بيانات مؤقتة ] -------
RUN mkdir -p data game spam \
    && chown -R www-data:www-data /app/data /app/game /app/spam \
    && touch msgs.json game.json \
    && chown www-data:www-data msgs.json game.json
# ------- [ نهاية التحذير ] -------

# تعيين المستخدم
USER www-data

# الأمر الافتراضي لتشغيل البوت
CMD ["php", "index.php"]
