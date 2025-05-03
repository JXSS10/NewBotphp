# 1. استخدم صورة PHP CLI حديثة وخفيفة كنقطة بداية
FROM php:8.1-cli-alpine AS builder

# ---------------------------------------------------------------------
# المرحلة 1: تثبيت الأدوات الأساسية، PHP، Python، Supervisor
# ---------------------------------------------------------------------
RUN apk update && apk add --no-cache \
    # أدوات أساسية
    git \
    unzip \
    # تثبيت Python و Pip
    python3 \
    py3-pip \
    # تثبيت Supervisor
    supervisor \
    # مكتبات تشغيل PHP (إذا لزم الأمر لاحقًا)
    libpng \
    libjpeg-turbo \
    freetype \
    libzip \
    # مكتبات تطوير PHP (للتثبيت)
    curl-dev \
    oniguruma-dev \
    libzip-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    # تثبيت امتدادات PHP الأساسية (و GD/Zip إذا كنت تعتقد أنك ستحتاجها)
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) curl mbstring zip gd \
    # إزالة حزم التطوير لتقليل الحجم
    && apk del --purge \
        curl-dev \
        oniguruma-dev \
        libzip-dev \
        libpng-dev \
        libjpeg-turbo-dev \
        freetype-dev

# تثبيت Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# تعيين مجلد العمل
WORKDIR /app

# ---------------------------------------------------------------------
# المرحلة 2: تثبيت اعتمادات PHP (Composer)
# ---------------------------------------------------------------------
COPY composer.json composer.lock* ./
# تشغيل composer install - تجاهل الخطأ إذا لم يكن composer.json موجودًا أو صالحًا مؤقتًا
RUN composer install --no-interaction --no-dev --optimize-autoloader || echo "Composer install failed or composer.json not found, continuing..."

# ---------------------------------------------------------------------
# المرحلة 3: تثبيت اعتمادات Python (pip)
# ---------------------------------------------------------------------
COPY requirements.txt ./
# تثبيت الحزم من requirements.txt - تجاهل الخطأ إذا لم يكن الملف موجودًا
RUN pip3 install --no-cache-dir -r requirements.txt || echo "requirements.txt not found or pip install failed, continuing..."

# ---------------------------------------------------------------------
# المرحلة 4: نسخ الكود وتهيئة Supervisor
# ---------------------------------------------------------------------
# نسخ باقي كود التطبيق (PHP و Python)
COPY . .

# نسخ ملفات تهيئة Supervisor (يجب إنشاؤها في مشروعك)
COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY php-bot.conf /etc/supervisor/conf.d/php-bot.conf
# أضف ملفات .conf أخرى إذا كان لديك عمليات Python إضافية (مثل gunicorn و main.py)
# COPY python-worker.conf /etc/supervisor/conf.d/python-worker.conf
# COPY gunicorn.conf /etc/supervisor/conf.d/gunicorn.conf

# ---------------------------------------------------------------------
# المرحلة 5: إعداد المجلدات والأذونات (مع التحذير)
# ---------------------------------------------------------------------
# ------- [ تحذير هام جداً - بيانات مؤقتة ] -------
RUN mkdir -p data game spam \
    && chown -R www-data:www-data /app/data /app/game /app/spam \
    && touch msgs.json game.json \
    && chown www-data:www-data msgs.json game.json
# ------- [ نهاية التحذير ] -------

# ---------------------------------------------------------------------
# المرحلة 6: تشغيل Supervisor
# ---------------------------------------------------------------------
# تعريض المنفذ إذا كنت تستخدم Gunicorn أو خادم ويب آخر (عدله حسب الحاجة)
# EXPOSE 8000

# تشغيل Supervisor كعملية رئيسية
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
