# 1. استخدم صورة PHP CLI حديثة وخفيفة كنقطة بداية
FROM php:8.1-cli-alpine AS builder

# تحديث وتثبيت الأدوات الأساسية، تبعيات PHP، Python، Pip، و tini
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
    # أداة لإدارة العمليات بشكل أفضل (PID 1)
    tini \
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
# تشغيل composer install - التحقق من وجود الملف أولاً
RUN if [ -f composer.json ]; then \
        composer install --no-interaction --no-dev --optimize-autoloader; \
    else \
        echo "composer.json not found, skipping composer install."; \
    fi

# ---------------------------------------------------------------------
# تثبيت اعتمادات Python (pip) - بما في ذلك Gunicorn (بطريقة أكثر قوة)
# ---------------------------------------------------------------------
COPY requirements.txt ./
# الخطوة 1: حاول التثبيت من requirements.txt إذا كان موجودًا، ولكن لا تفشل البناء إذا فشل هذا الجزء
RUN if [ -f requirements.txt ]; then \
        echo "Attempting install from requirements.txt..."; \
        pip3 install --no-cache-dir -r requirements.txt || echo "pip install from requirements.txt failed or file empty, continuing..."; \
    else \
        echo "requirements.txt not found, skipping."; \
    fi

# الخطوة 2: قم دائمًا بتثبيت Gunicorn بشكل صريح للتأكيد
RUN echo "Ensuring gunicorn is installed..." && \
    pip3 install --no-cache-dir gunicorn

# الخطوة 3: التحقق من أن gunicorn قابل للتنفيذ وموجود في المسار
RUN echo "Verifying gunicorn command..." && \
    which gunicorn || (echo "ERROR: gunicorn command not found after installation!" && exit 1) && \
    gunicorn --version

# ---------------------------------------------------------------------
# نسخ الكود وإعداد المجلدات ونقطة الدخول
# ---------------------------------------------------------------------
# نسخ النص البرمجي لنقطة الدخول وإعطائه صلاحية التنفيذ
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# نسخ باقي كود التطبيق (PHP و Python)
COPY . .

# ------- [ تحذير هام جداً - بيانات مؤقتة ] -------
RUN mkdir -p data game spam \
    && chown -R www-data:www-data /app/data /app/game /app/spam \
    && touch msgs.json game.json \
    && chown www-data:www-data msgs.json game.json
# ------- [ نهاية التحذير ] -------

# تعيين المستخدم (بعد إنشاء الملفات كـ root ثم تغيير ملكيتها)
USER www-data

# تعيين نقطة الدخول لتشغيل النص البرمجي باستخدام tini
ENTRYPOINT ["tini", "--", "/usr/local/bin/entrypoint.sh"]

# لا حاجة لـ CMD الآن، ENTRYPOINT يتولى الأمر
# الأمر الافتراضي لتشغيل بوت PHP
#CMD gunicorn app:app & php index.php
