#!/usr/bin/env bash
# Widgetorium webapp entrypoint.
# Applies the runtime weakness toggles, then hands off to apache2-foreground.
set -euo pipefail

CERT_DIR=/etc/ssl/widgetorium
BAKED=/opt/widgetorium/certs
mkdir -p "$CERT_DIR"

# --- certificate selection (vuln 5 default, vuln 6 when EXPIRED_CERT=1) --------
if [ "${EXPIRED_CERT:-0}" = "1" ]; then
  echo "[entrypoint] using EXPIRED certificate variant"
  cp "$BAKED/expired.crt" "$CERT_DIR/server.crt"
  cp "$BAKED/expired.key" "$CERT_DIR/server.key"
else
  echo "[entrypoint] using self-signed CN-mismatch certificate variant"
  cp "$BAKED/selfsigned.crt" "$CERT_DIR/server.crt"
  cp "$BAKED/selfsigned.key" "$CERT_DIR/server.key"
fi
cp "$BAKED/dhparam-1024.pem" "$CERT_DIR/dhparam-1024.pem"
chmod 0644 "$CERT_DIR/server.crt" "$CERT_DIR/dhparam-1024.pem"
chmod 0600 "$CERT_DIR/server.key"

# --- weak TLS protocols and ciphers (vuln 7) --------------------------------
# Point the whole process at an openssl.cnf that drops the security level and
# re-enables TLS 1.0. With WEAK_TLS=0 we leave the system default in place.
if [ "${WEAK_TLS:-1}" = "1" ]; then
  echo "[entrypoint] weak TLS enabled (TLS 1.0/1.1 + legacy ciphers)"
  export OPENSSL_CONF="$BAKED/openssl-weak.cnf"
  # apache2-foreground execs a fresh env; persist it for the service too.
  echo "export OPENSSL_CONF=$BAKED/openssl-weak.cnf" > /etc/apache2/envvars.d-openssl 2>/dev/null || true
  if ! grep -q openssl-weak /etc/apache2/envvars; then
    echo "export OPENSSL_CONF=$BAKED/openssl-weak.cnf" >> /etc/apache2/envvars
  fi
fi

# --- HSTS (vuln 8: header omitted unless SEND_HSTS=1) -----------------------
HSTS_CONF=/etc/apache2/conf-enabled/widgetorium-hsts.conf
if [ "${SEND_HSTS:-0}" = "1" ]; then
  echo "[entrypoint] HSTS header enabled"
  echo 'Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"' > "$HSTS_CONF"
else
  rm -f "$HSTS_CONF"
fi

# --- planted /admin/.git (vuln 9: removed when PLANT_GIT=0) ----------------
if [ "${PLANT_GIT:-1}" = "1" ]; then
  if [ -d /var/www/html/admin/.git ]; then
    echo "[entrypoint] /admin/.git present"
  else
    echo "[entrypoint] WARNING: PLANT_GIT=1 but /admin/.git is missing from the image"
  fi
else
  echo "[entrypoint] PLANT_GIT=0, removing /admin/.git"
  rm -rf /var/www/html/admin/.git
fi

# --- shared FTP dropzone permissions (vuln 19) ----------------------------
# vsftpd writes as a different uid; make sure Apache can read and execute what
# lands there.
mkdir -p /var/www/html/uploads/ftp
chmod 0777 /var/www/html/uploads /var/www/html/uploads/ftp || true

echo "[entrypoint] toggles: EXPIRED_CERT=${EXPIRED_CERT:-0} WEAK_TLS=${WEAK_TLS:-1} SEND_HSTS=${SEND_HSTS:-0} PLANT_GIT=${PLANT_GIT:-1} VERBOSE_ERRORS=${VERBOSE_ERRORS:-1} SECOND_ORDER_SINK=${SECOND_ORDER_SINK:-1} WEAK_SESSIONS=${WEAK_SESSIONS:-1}"

exec "$@"
