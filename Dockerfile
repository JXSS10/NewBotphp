# 1. استخدم صورة PHP CLI حديثة وخفيفة كنقطة بداية
FROM php:8.1-cli-alpine AS builder

# تحديث وتثبيت الأدوات الأساسية، تبعيات PHP، Python، و Pip
RUN apk update && apk add --no-cache \
    # أدوات أساسية
    git \
    unzip \
    # تثبيت Python و Pip
    python3 \
    py3-pip \
    # مكتبات تشغيل PHP
    libpng \
    libjpeg-turbo \
    freetype \
    libzip \
    # مكتبات تطوير PHP (للتثبيت فقط)
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

# ---------------------------------------------------------------------
# تثبيت اعتمادات PHP (Composer)
# ---------------------------------------------------------------------
COPY composer.json composer.lock* ./
# تشغيل composer install - تجاهل الخطأ إذا لم يكن composer.json موجودًا أو صالحًا مؤقتًا
RUN composer install --no-interaction --no-dev --optimize-autoloader || echo "Composer install failed or composer.json not found, continuing..."

# ---------------------------------------------------------------------
# تثبيت اعتمادات Python (pip) - الجزء المضاف
# ---------------------------------------------------------------------
COPY requirements.txt ./
# تثبيت الحزم من requirements.txt - تجاهل الخطأ إذا لم يكن الملف موجودًا
RUN pip3 install --no-cache-dir -r requirements.txt || echo "requirements.txt not found or pip install failed, continuing..."

# ---------------------------------------------------------------------
# نسخ الكود وإعداد المجلدات
# ---------------------------------------------------------------------
# نسخ باقي كود التطبيق (PHP و Python)
COPY . .

# ------- [ تحذير هام جداً - بيانات مؤقتة ] -------
RUN mkdir -p data game spam \
    && chown -R www-data:www-data /app/data /app/game /app/spam \
    && touch msgs.json game.json \
    && chown www-data:www-data msgs.json game.json
# ------- [ نهاية التحذير ] -------

# تعيين المستخدم
USER www-data

# الأمر الافتراضي لتشغيل بوت PHP
CMD ["php", "index.php"]
