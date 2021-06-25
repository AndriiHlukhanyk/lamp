FROM phusion/baseimage:bionic-1.0.0
MAINTAINER Andrii Hlukhanyk <andrii.hlukhanyk@coidea.agency>
ENV REFRESHED_AT 2021-06-23

# based on phusion/baseimage:bionic-1.0.0
# MAINTAINER Phusion, Netherlands, https://www.phusion.nl/

# based on dgraziotin/lamp
# MAINTAINER Daniel Graziotin <daniel@ineed.coffee>

# fork of mattrayner/lamp
# MAINTAINER Matthew Rayner <matt@mattrayner.co.uk>

ENV DOCKER_USER_ID 501 
ENV DOCKER_USER_GID 20

ENV BOOT2DOCKER_ID 1000
ENV BOOT2DOCKER_GID 50

# Tweaks to give Apache/PHP write permissions to the app
RUN usermod -u ${BOOT2DOCKER_ID} www-data && \
    usermod -G staff www-data && \
    useradd -r mysql && \
    usermod -G staff mysql

RUN groupmod -g $(($BOOT2DOCKER_GID + 10000)) $(getent group $BOOT2DOCKER_GID | cut -d: -f1)
RUN groupmod -g ${BOOT2DOCKER_GID} staff

# Install packages
ENV DEBIAN_FRONTEND noninteractive
RUN add-apt-repository ppa:ondrej/php
RUN apt-get update && \
  apt-get -y upgrade && \
  apt-get -y install supervisor wget git pkg-config build-essential ssl-cert libmcrypt-dev libz-dev libpq-dev libicu-dev libssl-dev apache2 php7.4-xdebug curl memcached php-memcached libmemcached-tools libmemcached-dev libapache2-mod-php7.4 mysql-server php7.4 php7.4-curl php7.4-dev php-pear php7.4-dom php7.4-simplexml php7.4-ctype php7.4-cli php7.4-intl php7.4-xsl php7.4-imap php7.4-mysql pwgen php7.4-apc php7.4-gd php7.4-iconv php7.4-xml php7.4-mbstring php7.4-xmlwriter php7.4-apcu php7.4-gettext zip unzip php7.4-zip  && \
  apt-get -y autoremove && \
  echo "ServerName localhost" >> /etc/apache2/apache2.conf

RUN pecl channel-update pecl.php.net
RUN pecl search mcrypt
RUN yes '' | pecl install mcrypt-1.0.4

RUN echo 'extension=mcrypt.so' > /etc/php/7.4/mods-available/mcrypt.ini
RUN ln -s /etc/php/7.4/mods-available/mcrypt.ini /etc/php/7.4/apache2/conf.d/mcrypt.ini
RUN ln -s /etc/php/7.4/mods-available/mcrypt.ini /etc/php/7.4/cli/conf.d/mcrypt.ini
RUN openssl dhparam -out /etc/ssl/private/dhparams.pem 2048
RUN chmod 600 /etc/ssl/private/dhparams.pem

# XDEBUG
RUN echo "xdebug.default_enable=1" >> /etc/php/7.4/apache2/php.ini
RUN echo "xdebug.default_enable=1" >> /etc/php/7.4/cli/php.ini

RUN echo "xdebug.profiler_enable=1" >> /etc/php/7.4/apache2/php.ini
RUN echo "xdebug.profiler_enable=1" >> /etc/php/7.4/cli/php.ini

RUN echo "xdebug.remote_enable=1" >> /etc/php/7.4/apache2/php.ini
RUN echo "xdebug.remote_enable=1" >> /etc/php/7.4/cli/php.ini

RUN echo "xdebug.remote_connect_back=0" >> /etc/php/7.4/apache2/php.ini
RUN echo "xdebug.remote_connect_back=0" >> /etc/php/7.4/cli/php.ini

RUN echo "xdebug.idekey=\"VSCODE\"" >> /etc/php/7.4/apache2/php.ini
RUN echo "xdebug.idekey=\"VSCODE\"" >> /etc/php/7.4/cli/php.ini

RUN echo "xdebug.remote_port=9000" >> /etc/php/7.4/apache2/php.ini
RUN echo "xdebug.remote_port=9000" >> /etc/php/7.4/cli/php.ini

RUN echo "xdebug.remote_autostart=1" >> /etc/php/7.4/apache2/php.ini
RUN echo "xdebug.remote_autostart=1" >> /etc/php/7.4/cli/php.ini

RUN echo "xdebug.remote_handler=dbgp" >> /etc/php/7.4/apache2/php.ini
RUN echo "xdebug.remote_handler=dbgp" >> /etc/php/7.4/cli/php.ini

# DockerNAT gateway IP
RUN echo "xdebug.remote_host=host.docker.internal" >> /etc/php/7.4/apache2/php.ini
RUN echo "xdebug.remote_host=host.docker.internal" >> /etc/php/7.4/cli/php.ini

# Update CLI PHP to use 7.4
RUN ln -sfn /usr/bin/php7.4 /etc/alternatives/php

# Add image configuration and scripts
ADD supporting_files/start-apache2.sh /start-apache2.sh
ADD supporting_files/start-memcached.sh /start-memcached.sh
ADD supporting_files/start-mysqld.sh /start-mysqld.sh
ADD supporting_files/run.sh /run.sh
RUN chmod 755 /*.sh
ADD supporting_files/supervisord-apache2.conf /etc/supervisor/conf.d/supervisord-apache2.conf
ADD supporting_files/supervisord-memcached.conf /etc/supervisor/conf.d/supervisord-memcached.conf
ADD supporting_files/supervisord-mysqld.conf /etc/supervisor/conf.d/supervisord-mysqld.conf

# Set PHP timezones to Europe/London
RUN sed -i "s/;date.timezone =/date.timezone = Europe\/London/g" /etc/php/7.4/apache2/php.ini
RUN sed -i "s/;date.timezone =/date.timezone = Europe\/London/g" /etc/php/7.4/cli/php.ini

# Remove pre-installed database
RUN rm -rf /var/lib/mysql

# Add MySQL utils
ADD supporting_files/create_mysql_users.sh /create_mysql_users.sh
RUN chmod 755 /*.sh

# Add phpmyadmin
ENV PHPMYADMIN_VERSION=5.1.1
RUN wget -O /tmp/phpmyadmin.tar.gz https://files.phpmyadmin.net/phpMyAdmin/${PHPMYADMIN_VERSION}/phpMyAdmin-${PHPMYADMIN_VERSION}-all-languages.tar.gz
RUN tar xfvz /tmp/phpmyadmin.tar.gz -C /var/www
RUN ln -s /var/www/phpMyAdmin-${PHPMYADMIN_VERSION}-all-languages /var/www/phpmyadmin
RUN mv /var/www/phpmyadmin/config.sample.inc.php /var/www/phpmyadmin/config.inc.php

# Add composer
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
    php composer-setup.php && \
    php -r "unlink('composer-setup.php');" && \
    mv composer.phar /usr/local/bin/composer

ENV MYSQL_PASS:-$(pwgen -s 12 1)
# config to enable .htaccess
ADD supporting_files/apache_default /etc/apache2/sites-available/000-default.conf
RUN a2enmod deflate expires headers rewrite ssl

# Configure /app folder with sample app
RUN mkdir -p /app && rm -fr /var/www/html && ln -s /app /var/www/html
ADD app/ /app

# Adding memcached daemon
#RUN mkdir /etc/service/memcached
#COPY start-memcached.sh /etc/service/memcached/run
#RUN chmod +x /etc/service/memcached/run

# Environment variables to configure php
ENV PHP_UPLOAD_MAX_FILESIZE 16M
ENV PHP_POST_MAX_SIZE 32M

# Add volumes for the app and MySql
VOLUME  ["/etc/mysql", "/var/lib/mysql", "/app" ]

EXPOSE 80 3306 11211 9000
CMD ["/run.sh"]
