# ملف Dockerfile مع إضافة أمر تثبيت gunicorn بشكل صريح

FROM php:8.1-cli-alpine

# تحديث وتثبيت الأدوات الأساسية، تبعيات PHP، Python، Pip
RUN apk update && apk add --no-cache \
    # أدوات أساسية
    git unzip \
    # تثبيت Python و Pip
    python3 py3-pip \
    # مكتبات تشغيل PHP
    libpng libjpeg-turbo freetype libzip \
    # مكتبات تطوير PHP (للتثبيت فقط)
    libzip-dev curl-dev libpng-dev libjpeg-turbo-dev freetype-dev oniguruma-dev \
    # إعداد وتثبيت الامتدادات بما فيها gd و zip
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd zip curl mbstring \
    # حذف حزم التطوير فقط، والإبقاء على مكتبات التشغيل
    && apk del --purge \
    libzip-dev curl-dev libpng-dev libjpeg-turbo-dev freetype-dev oniguruma-dev \
    # تنظيف مخزن apk المؤقت
    && rm -rf /var/cache/apk/*

# تثبيت Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# تعيين مجلد العمل
WORKDIR /app

# تثبيت اعتمادات PHP (Composer)
COPY composer.json composer.lock* ./
RUN composer install --no-interaction --no-dev --optimize-autoloader || echo "Composer install failed or composer.json not found, continuing..."

# --- تثبيت اعتمادات Python (pip) ---

# 1. تثبيت gunicorn بشكل صريح ومباشر
#    سيضمن هذا الأمر محاولة تثبيت gunicorn. سيفشل البناء إذا لم ينجح.
RUN pip3 install --no-cache-dir gunicorn

# 2. تثبيت باقي الاعتمادات من requirements.txt (إن وجدت)
COPY requirements.txt ./
#    تم إزالة `|| echo "..."` لضمان فشل البناء إذا لم يتم تثبيت الحزم الأخرى.
#    إذا كان requirements.txt لا يحتوي إلا على gunicorn، يمكنك إزالة هذا الجزء
#    إذا كنت متأكدًا من أنك ثبتته في الخطوة السابقة. لكن من الأفضل إبقاؤه
#    إذا كان الملف يحتوي على حزم أخرى.
RUN pip3 install --no-cache-dir -r requirements.txt

# ------------------------------------

# نسخ الكود وإعداد المجلدات
COPY . .

# --- إعداد الأذونات ---
RUN mkdir -p data game spam \
    && chown -R www-data:www-data /app/data /app/game /app/spam \
    && touch msgs.json game.json \
    && chown www-data:www-data msgs.json game.json
# ---------------------

# تعيين المستخدم
USER www-data

# الأمر الافتراضي لتشغيل Gunicorn في الخلفية و PHP في المقدمة
# (تأكد من أن 'app:app' صحيح لتطبيقك)
CMD sh -c 'gunicorn app:app & php index.php'
