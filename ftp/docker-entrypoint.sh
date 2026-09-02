#!/bin/sh
set -eu

FTP_USER="${FTP_USER:-ftpuser}"
FTP_PASS="${FTP_PASS:-ftpuser}"

# vuln 16: (re)create the account and set the weak password from the environment.
if ! id "$FTP_USER" >/dev/null 2>&1; then
  adduser -D -h "/home/$FTP_USER" -s /bin/sh "$FTP_USER"
fi
echo "${FTP_USER}:${FTP_PASS}" | chpasswd
grep -qx /bin/sh /etc/shells || echo /bin/sh >> /etc/shells
echo "[entrypoint] ftp user ${FTP_USER} ready (password from FTP_PASS)"

# vuln 15 + 19: anonymous users land in a read-only root (/srv/ftp) with a
# world-writable upload/ subdir. vsftpd refuses to serve a writable chroot
# root, so the root itself must stay non-writable; the writable bit is on the
# subdir. Apache reads /srv/ftp/upload as www-data through the shared volume.
mkdir -p /srv/ftp/upload
chmod 0555 /srv/ftp
chmod 0777 /srv/ftp/upload
chown ftp:ftp /srv/ftp/upload 2>/dev/null || true

# vsftpd needs this to exist and be non-writable.
mkdir -p /var/run/vsftpd/empty
chmod 0555 /var/run/vsftpd/empty

echo "[entrypoint] starting vsftpd (anon upload on, no TLS, no chroot jail)"
exec "$@"
