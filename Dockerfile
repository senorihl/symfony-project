FROM php:8.4-fpm

ARG UID
ARG GID

RUN addgroup --gid ${GID} --system developer
RUN adduser --gid ${GID} --system --disabled-password --shell /bin/sh --home /opt/developer --uid ${UID} developer

RUN --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    --mount=type=cache,target=/var/cache/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    libfcgi-bin
ADD --chmod=777 https://raw.githubusercontent.com/renatomefi/php-fpm-healthcheck/master/php-fpm-healthcheck /usr/local/bin/php-fpm-healthcheck

COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

RUN install-php-extensions \
    @composer apcu opcache pdo pdo_mysql pdo_pgsql pdo_sqlite sqlite3 zip

COPY --from=node:lts /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=node:lts /usr/local/bin/node /usr/local/bin/node
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm
RUN npm install -g npm

HEALTHCHECK --interval=30s --timeout=3s --start-interval=5s --start-period=5s \
    CMD php-fpm-healthcheck || exit 1
