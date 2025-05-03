# استخدم نفس القاعدة الأساسية
FROM php:8.1-cli-alpine AS builder

# تحديث وتثبيت الأدوات الأساسية، تبعيات PHP، Python، Pip، و Supervisor
RUN apk update && apk add --no-cache \
    # أدوات أساسية
    git unzip \
    # تثبيت Python و Pip
    python3 py3-pip \
    # مكتبات تشغيل PHP
    libpng libjpeg-turbo freetype libzip \
    # مكتبات تطوير PHP (للتثبيت فقط)
    libzip-dev curl-dev libpng-dev libjpeg-turbo-dev freetype-dev oniguruma-dev \
    # تثبيت Supervisor لإدارة العمليات
    supervisor \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd zip curl mbstring \
    # حذف حزم التطوير فقط، والإبقاء على مكتبات التشغيل
    && apk del --purge \
    libzip-dev curl-dev libpng-dev libjpeg-turbo-dev freetype-dev oniguruma-dev \
    # تنظيف مخزن مؤقت لـ apk
    && rm -rf /var/cache/apk/*

# تثبيت Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# تعيين مجلد العمل
WORKDIR /app

# تثبيت اعتمادات PHP (Composer)
COPY composer.json composer.lock* ./
# ملاحظة: إذا فشل composer، سيتوقف البناء. أزل || echo "..." إذا كان composer إلزاميًا
RUN composer install --no-interaction --no-dev --optimize-autoloader || echo "Composer install failed or composer.json not found, continuing..."

# تثبيت اعتمادات Python (pip)
COPY requirements.txt ./
# ملاحظة: إذا فشل pip، سيتوقف البناء. أزل || echo "..." إذا كان requirements.txt إلزاميًا
RUN pip3 install --no-cache-dir -r requirements.txt || echo "requirements.txt not found or pip install failed, continuing..."
# --- التحقق من gunicorn (خطوة اختيارية للمساعدة في التصحيح) ---
# يمكنك إضافة هذا السطر مؤقتًا للتحقق من مكان تثبيت gunicorn أثناء البناء
# RUN which gunicorn
# -----------------------------------------------------------------

# نسخ الكود وإعداد المجلدات
COPY . .

# --- إعداد الأذونات ---
# من الأفضل إنشاء المجلدات قبل نسخ الكود إليها إذا كانت جزءًا من الكود
RUN mkdir -p storage/logs data game spam \
    && chown -R www-data:www-data /app/storage /app/data /app/game /app/spam \
    && touch /app/msgs.json /app/game.json \
    && chown www-data:www-data /app/msgs.json /app/game.json

# نسخ ملف إعدادات Supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# تعيين المستخدم (Supervisord سيبدأ كـ root ولكنه سيشغل العمليات كـ www-data كما هو محدد في .conf)
# USER www-data  <-- علّق هذا السطر أو أزله، دع Supervisord يبدأ كـ root لإدارة العمليات بشكل صحيح

# تعريض المنفذ الذي يستمع إليه Gunicorn (افتراضيًا 8000)
EXPOSE 8000

# تشغيل Supervisord في المقدمة
# سيتولى هو تشغيل PHP و Gunicorn كما هو محدد في ملف الإعدادات
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
#CMD gunicorn app:app & php index.php
