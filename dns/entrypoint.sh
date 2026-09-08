#!/bin/sh
# Widgetorium DNS entrypoint.
# The mounted configs are read-only. Copy them to a writable path, apply the
# OPEN_AXFR toggle, sanity-check, then hand off to named in the foreground.
set -e

SRC=/etc/bind.src
RUN=/etc/bind.run

mkdir -p "$RUN"
cp -r "$SRC/." "$RUN/"
# The mounted files inherit the host's permissions/umask. named drops to the
# `bind` user, so force the copy readable regardless of how it arrived.
chown -R bind:bind "$RUN"
chmod -R a+rX "$RUN"

if [ "${OPEN_AXFR:-1}" = "0" ]; then
    echo "[dns] OPEN_AXFR=0 -> locking zone transfers on corp.widgetorium.lab"
    sed -i 's/allow-transfer { any; };.*BUG20_AXFR/allow-transfer { none; };/' "$RUN/named.conf"
else
    echo "[dns] OPEN_AXFR=1 -> corp.widgetorium.lab zone transfer is WIDE OPEN (bug 20)"
fi

named-checkconf "$RUN/named.conf"
named-checkzone corp.widgetorium.lab "$RUN/zones/db.corp.widgetorium.lab" >/dev/null
named-checkzone widgetorium.lab "$RUN/zones/db.widgetorium.lab" >/dev/null

# Start as root so the pid file and rndc key open cleanly, then drop to bind.
mkdir -p /run/named && chown bind:bind /run/named 2>/dev/null || true
exec named -g -u bind -c "$RUN/named.conf"
