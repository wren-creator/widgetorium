# Widgetorium FTP: intentionally misconfigured vsftpd.
#
# Alpine base. Alpine's containerised vsftpd is the well-tested combination for
# Docker; the Debian 3.0.3 build segfaults intermittently under connection load
# on some hosts.
FROM alpine:3.20

RUN apk add --no-cache vsftpd shadow \
 && mkdir -p /srv/ftp/upload /var/run/vsftpd/empty /var/log /var/ftp \
 && chmod 0555 /var/run/vsftpd/empty \
 && chmod 0777 /srv/ftp/upload \
 && touch /var/log/vsftpd.log

# vuln 16: the service account. Password is set at runtime from FTP_PASS by the
# entrypoint (defaults to "ftpuser"). Shell is a real one and is listed in
# /etc/shells so PAM does not block the login.
RUN adduser -D -h /home/ftpuser -s /bin/sh ftpuser \
 && echo /bin/sh >> /etc/shells

COPY vsftpd.conf /etc/vsftpd.conf
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 21 21100-21110
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["vsftpd", "/etc/vsftpd.conf"]
