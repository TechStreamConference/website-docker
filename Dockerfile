FROM php:8.2-apache-bookworm

RUN apt-get -y update \
    && apt-get install -y libicu-dev \
    && docker-php-ext-configure intl \
    && docker-php-ext-install intl \
    && rm -rf /var/cache/apt/archives /var/lib/apt/lists/*
RUN apt-get -y update \
    && apt-get install -y default-libmysqlclient-dev \
    && docker-php-ext-configure mysqli \
    && docker-php-ext-install mysqli \
    && rm -rf /var/cache/apt/archives /var/lib/apt/lists/*
RUN apt-get -y update \
    && apt-get install -y libzip-dev unzip \
    && docker-php-ext-configure zip \
    && docker-php-ext-install zip \
    && rm -rf /var/cache/apt/archives /var/lib/apt/lists/*

# RUN cat /usr/local/etc/php/php.ini-production | \
#     sed 's/;extension=intl/extension=intl/g' | \
#     sed 's/;extension=mysqli/extension=mysqli/g' | \
#     sed 's/;extension=zip/extension=zip/g' > /usr/local/etc/php/php.ini

RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash 
ENV NVM_DIR="/root/.nvm" NODE_VERSION="v20.17.0"
RUN . $NVM_DIR/nvm.sh && nvm install $NODE_VERSION
ENV PATH="$NVM_DIR/versions/node/$NODE_VERSION/bin:$PATH"

COPY install-composer.sh /root/install-composer.sh
RUN /root/install-composer.sh

COPY start-servers.sh /usr/local/bin/start-servers.sh
CMD start-servers.sh

COPY app-host.conf /etc/apache2/conf-available/app-host.conf
RUN cd /etc/apache2/conf-enabled/ && ln -s ../conf-available/app-host.conf app-host.conf
RUN cd /etc/apache2/mods-enabled/ && ln -s ../mods-available/proxy.load proxy.load && ln -s ../mods-available/proxy_http.load proxy_http.load 
RUN ls -la /etc/apache2/mods-enabled/ && apachectl configtest

RUN mkdir -p backend
COPY website-backend/composer.* backend/
RUN composer -d backend install

RUN mkdir -p frontend
COPY website-frontend/package* frontend/
RUN cd frontend && npm install

COPY website-backend/ backend/
COPY website-frontend/ frontend/
