FROM php:7.2.0-apache-stretch as builder

# The version of php-composer to install.
ARG COMPOSER_VERSION=1.1.2

# The version of nodejs to install.
ARG NODE_VERSION=node_8.x

# Install dependencies to install dependencies.
RUN apt-get update && apt-get install --yes \
    gnupg2 \
    apt-transport-https

# Add node repository.
RUN curl --silent https://deb.nodesource.com/gpgkey/nodesource.gpg.key \
    | apt-key add - && \
    echo "deb https://deb.nodesource.com/${NODE_VERSION} stretch main" \
    | tee /etc/apt/sources.list.d/nodesource.list && \
    echo "deb-src https://deb.nodesource.com/${NODE_VERSION} stretch main" \
    | tee --append /etc/apt/sources.list.d/nodesource.list

# Add yarn repository.
RUN curl --silent --show-error https://dl.yarnpkg.com/debian/pubkey.gpg \
    | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" \
    | tee /etc/apt/sources.list.d/yarn.list

# These are dependencies needed both at build time and at runtime.
ARG RUNTIME_DEPS="\
    libpng-dev \
    libxml2-dev \
    zlib1g-dev \
    libcurl4-openssl-dev"

# Install dependencies.
RUN apt-get update && \
    apt-get install --yes \
    nodejs \
    yarn \
    git \
    ${RUNTIME_DEPS}

# Install composer from getcomposer.org. An apk package is only available in
# edge (> 3.7).
RUN curl -sS https://getcomposer.org/installer \
    | php -- \
    --install-dir=/usr/local/bin \
    --filename=composer \
    --version=${COMPOSER_VERSION} && \
    chmod +x /usr/local/bin/composer && \
    composer --version

ARG PHP_BUILD_DEPS="exif zip mbstring curl xml"

# The repo version wasn't working so using docker-php-ext-install instead. Not
# using docker-php-ext-install for every extension because it is badly
# documented.
RUN docker-php-ext-install ${PHP_BUILD_DEPS}

# Change to a restricted user.
# USER www-data

# Clone the koel repository.
RUN git clone --recurse-submodules https://github.com/koel/koel.git /tmp/koel

# Place artifacts here.
WORKDIR /tmp/koel

# RUN [ "git", "checkout", "v3.7.2" ]
RUN [ "git", "checkout", "v4.0.0" ]

# Install runtime dependencies.
RUN composer install
RUN npm install
RUN npm audit fix --force

# The runtime image.
FROM php:7.2.0-apache-stretch

# These are dependencies needed both at build time and at runtime. This is
# repeated because docker doesn't seem to have a way to share args across build
# contexts.
ARG RUNTIME_DEPS="\
    libcurl4-openssl-dev \
    zlib1g-dev \
    libxml2-dev \
    faad \
    ffmpeg"

ARG PHP_RUNTIME_DEPS="\
    mbstring \
    curl \
    xml \
    zip \
    pdo \
    pdo_mysql \
    exif"

# Install dependencies.
RUN apt-get update && \
    apt-get install --yes ${RUNTIME_DEPS} && \
    docker-php-ext-install ${PHP_RUNTIME_DEPS} && \
    apt-get clean

# Copy artifacts from build stage.
COPY --from=builder /tmp/koel /var/www/html

# Remove configuration file. All configuration should be passed in as
# environment variables or a bind mounted file at runtime.
# RUN rm /var/www/html/.env

# Koel makes use of Larvel's pretty URLs. This requires some additional
# configuration: https://laravel.com/docs/4.2#pretty-urls
COPY ./.htaccess /var/www/html

# COPY .env .env

# https://stackoverflow.com/a/48868602/7092954
# RUN echo "ServerName 0.0.0.0" >> /etc/apache2/apache2.conf

# Fix permissions.
RUN chown -R www-data:www-data /var/www/html
RUN a2enmod rewrite
RUN service apache2 restart

# Setup bootstrap script.
COPY koel-entrypoint /usr/local/bin/

ENTRYPOINT ["koel-entrypoint"]
CMD ["apache2-foreground"]

EXPOSE 80
