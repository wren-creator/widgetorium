# Widgetorium web application: Apache + PHP 8 "widget store".
#
# Pinned to the Bullseye variant on purpose. It ships OpenSSL 1.1.1, which still
# carries RC4 / 3DES / EXPORT ciphers. The Bookworm image (OpenSSL 3) has several
# of those compiled out, so vuln 7 (weak-cipher findings under testssl.sh) would
# silently not reproduce. Do not "upgrade" this tag without checking that.
FROM php:8.2-apache-bullseye

# curl for the healthcheck; git for the planted .git history; faketime to
# backdate the expired certificate; openssl for cert generation.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl git faketime openssl \
 && rm -rf /var/lib/apt/lists/*

RUN a2enmod ssl headers rewrite \
 && a2ensite default-ssl

RUN docker-php-ext-install pdo_mysql mysqli

# Apache vhosts and PHP config.
COPY apache/000-default.conf     /etc/apache2/sites-available/000-default.conf
COPY apache/default-ssl.conf     /etc/apache2/sites-available/default-ssl.conf
COPY apache/dotfiles-allow.conf  /etc/apache2/conf-available/dotfiles-allow.conf
RUN a2enconf dotfiles-allow
COPY php/widgetorium.ini          /usr/local/etc/php/conf.d/widgetorium.ini

# Certificate material and helper scripts.
COPY certs/  /opt/widgetorium/certs/
COPY tools/  /opt/widgetorium/tools/

# Generate both certificate pairs and bake them into the image.
RUN bash /opt/widgetorium/certs/gen-certs.sh

# The site itself.
COPY src/ /var/www/html/

# Plant the /admin/.git history at build time (secret in commit 1, "removed" in
# commit 2). Doing this in the build avoids a nested repo in the source tree.
RUN bash /opt/widgetorium/tools/plant-git.sh

RUN chown -R www-data:www-data /var/www/html \
 && mkdir -p /var/www/html/uploads/ftp \
 && chmod -R 0777 /var/www/html/uploads

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 80 443
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]
