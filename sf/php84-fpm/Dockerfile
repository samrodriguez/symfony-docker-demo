# ╔══════════════════════════════════════════════════════════════════════╗
# 1. ETAPA BASE — Núcleo del sistema, Drivers y Extensiones PHP
#    (Compartido por Desarrollo y Producción)
# ╚══════════════════════════════════════════════════════════════════════╝
FROM php:8.4-fpm-bookworm AS base

ENV TZ=America/El_Salvador \
    ACCEPT_EULA=Y \
    DEBIAN_FRONTEND=noninteractive

# Instalamos utilidades básicas, dependencias del sistema y libfcgi-bin (CRÍTICO para el Healthcheck)
RUN apt-get update && apt-get install -y --no-install-recommends \
        tzdata ca-certificates gnupg2 apt-transport-https curl wget unzip git vim bash libfcgi-bin \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
    && rm -rf /var/lib/apt/lists/*

# Instalación Unificada de Extensiones PHP (Usando mlocati)
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/bin/
RUN install-php-extensions \
    gd pdo pdo_mysql pdo_pgsql zip mbstring xml opcache ldap xsl soap intl sodium imagick redis amqp sqlsrv pdo_sqlsrv \
    && rm -rf /usr/bin/install-php-extensions /var/log/* /tmp/* /var/tmp/* /var/lib/apt/lists/*

WORKDIR /var/www/html


# ╔══════════════════════════════════════════════════════════════════════╗
# 2. ETAPA DEV — Entorno de Desarrollo Local
#    (Pesado, con Node, Composer, Symfony CLI y usuario developer)
# ╚══════════════════════════════════════════════════════════════════════╝
FROM base AS dev

ENV COMPOSER_VERSION=2.10.3 \
    NODE_VERSION=24.21.0

ARG UID=1000
ARG GID=1000
ARG APPENV=dev

# Instalamos Node/Yarn, Composer, Symfony CLI y herramientas de desarrollo
RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
    && apt-get install -y --no-install-recommends \
        nodejs \
        ripgrep \
    && npm install -g corepack@latest \
    && corepack enable \
    && corepack prepare yarn@stable --activate \
    && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer --version=${COMPOSER_VERSION} \
    && wget https://get.symfony.com/cli/installer -O - | bash \
    && mv /root/.symfony*/bin/symfony /usr/local/bin/symfony \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /root/.cache

# Configuración de usuario desarrollador y permisos locales
RUN groupadd -g ${GID} developer \
    && useradd -u ${UID} -g developer -s /bin/bash -m developer \
    && usermod -aG www-data developer \
    && mkdir -p /var/www/html/public/media /var/www/html/var/cache /var/www/html/var/log \
                /var/www/html/node_modules /home/developer/.composer/cache /home/developer/.npm \
    && chown -R developer:developer /var/www/html /home/developer \
    && chmod -R 775 /var/www/html

# Archivos de configuración PHP para Dev
COPY php/dev/php.ini /usr/local/etc/php/conf.d/php.ini
COPY php/dev/opcache.ini /usr/local/etc/php/conf.d/opcache.ini

USER developer
EXPOSE 9000
CMD ["php-fpm"]


# ╔══════════════════════════════════════════════════════════════════════╗
# 3. ETAPA BUILDER — Compilación de Producción
# ╚══════════════════════════════════════════════════════════════════════╝
# NOTA: Esta etapa requiere un build context adicional llamado 'codigo_fuente'.
# En docker-compose.prod.yml se pasa así:
#   additional_contexts:
#     codigo_fuente: /ruta/al/codigo
FROM base AS builder

ENV COMPOSER_VERSION=2.10.2 \
    NODE_VERSION=24.19.0 \
    COMPOSER_MEMORY_LIMIT=-1

# Instalamos herramientas de compilación
RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && npm install -g corepack@latest && corepack enable && corepack prepare yarn@stable --activate \
    && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer --version=${COMPOSER_VERSION}

# Caché de manifiestos PHP
COPY --from=codigo_fuente composer.json composer.lock symfony.lock* ./
RUN composer install --no-dev --no-scripts --prefer-dist

# Ingesta del código y frontend
COPY --from=codigo_fuente . .
RUN rm -f .env.local.php .env.local .env.*.local .env.dev .env.test \
    && yarn install && yarn build && rm -rf node_modules /root/.yarn /root/.cache \
    && php -d memory_limit=-1 /usr/local/bin/composer dump-autoload --optimize --classmap-authoritative --no-dev


# ╔══════════════════════════════════════════════════════════════════════╗
# 4. ETAPA APP (PRODUCCIÓN) — Runtime ultra-ligero y blindado
# ╚══════════════════════════════════════════════════════════════════════╝
FROM base AS app

ARG APPENV=prod

# Purga de herramientas de red que quedaron en la base (Seguridad extra para Prod)
RUN apt-get purge -y --auto-remove curl gnupg git wget unzip \
    && rm -rf /var/lib/apt/lists/*

# Archivos de configuración PHP para Prod
COPY php84-fpm/php/prod/php.ini /usr/local/etc/php/conf.d/zz-php.ini
COPY php84-fpm/php/prod/opcache.ini /usr/local/etc/php/conf.d/zz-opcache.ini

# Reasignación POSIX
RUN usermod -u 1000 www-data && groupmod -g 1000 www-data \
    && mkdir -p /var/run/php /var/log/php && chown -R www-data:www-data /var/run/php /var/log/php

# Código horneado desde el builder
COPY --from=builder --chown=www-data:www-data /var/www/html /var/www/html

# Directorios de la app
RUN cp -a /var/www/html/public /var/www/html/public-staging \
    && chown -R www-data:www-data /var/www/html/public-staging \
    && mkdir -p /var/www/html/public/media /var/www/html/var/cache /var/www/html/var/log \
    && chown -R www-data:www-data /var/www/html/var /var/www/html/public/media \
    && chmod -R 775 /var/www/html/var /var/www/html/public/media

# Entrypoint
COPY --chmod=755 php84-fpm/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

# --- NUEVO: Healthcheck embebido para entornos sin Docker Compose (Swarm/K8s) ---
HEALTHCHECK --interval=15s --timeout=3s --retries=3 --start-period=10s \
  CMD SCRIPT_NAME=/ping SCRIPT_FILENAME=/ping REQUEST_METHOD=GET cgi-fcgi -bind -connect 127.0.0.1:9000 || exit 1

USER www-data
EXPOSE 9000
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["php-fpm"]


# ╔══════════════════════════════════════════════════════════════════════╗
# 5. ETAPA NGINX (PRODUCCIÓN) — Servidor Web Inmutable
# ╚══════════════════════════════════════════════════════════════════════╝
FROM nginx:1.30-alpine AS nginx

COPY --from=builder /var/www/html/public /var/www/html/public
COPY nginx/default.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]