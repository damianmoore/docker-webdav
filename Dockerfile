FROM ghcr.io/linuxserver/nginx:1.30.4-r1-ls380

# add packages via apk, and drop PHP: WebDAV never uses it, and the base
# image's php-fpm is only attack surface (PHP2Shell, CVE-2026-109618/109619)
RUN set -eux; \
    apk add --no-cache \
    apache2-utils; \
    apk del --no-cache $(apk info | grep '^php'); \
    rm -rf /etc/s6-overlay/s6-rc.d/svc-php-fpm \
        /etc/s6-overlay/s6-rc.d/user/contents.d/svc-php-fpm

# customize nginx
COPY files/vhost.conf /config/nginx/site-confs/default
RUN set -eux; \
    rm -rf /var/www/*; \
    mkdir /var/www/dav; \
    chmod -R a+rwX /var/www

# docker entrypoint (custom-cont-init.d skips non-executable scripts)
COPY --chmod=755 files/create-htpasswd.sh /custom-cont-init.d/

# exposed ports & volumes
EXPOSE 80
VOLUME /var/www/dav
