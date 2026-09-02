#!/usr/bin/env bash
# Health, reachability, and the loopback bind audit.
set -uo pipefail
cd "$(dirname "$0")"
source ./lib.sh

require_docker

info "containers"
dc -f docker-compose.yml ps

echo
info "endpoint checks"
code="$(curl -fsS -o /dev/null -w '%{http_code}' http://127.0.0.1:8080/health.php 2>/dev/null || true)"
[ "$code" = "200" ] && ok "http  127.0.0.1:8080  ($code)" || bad "http  127.0.0.1:8080  ($code)"
code="$(curl -ksS -o /dev/null -w '%{http_code}' https://127.0.0.1:8443/health.php 2>/dev/null || true)"
[ "$code" = "200" ] && ok "https 127.0.0.1:8443  ($code)" || bad "https 127.0.0.1:8443  ($code)"
if (exec 3<>/dev/tcp/127.0.0.1/21) 2>/dev/null; then ok "ftp   127.0.0.1:21    (open)"; exec 3>&- || true
else bad "ftp   127.0.0.1:21    (closed)"; fi

echo
info "loopback bind audit"
AUDIT_FAIL=0
while read -r name ports; do
  [ -z "$ports" ] && continue
  # ports looks like: 127.0.0.1:8080->80/tcp, 127.0.0.1:8443->443/tcp
  if printf '%s' "$ports" | grep -Eq '(^|[, ])0\.0\.0\.0:|(^|[, ])\[?::\]?:|(^|[, ])\*:'; then
    bad "$name exposes a non-loopback binding: $ports"
    AUDIT_FAIL=1
  else
    ok "$name  $ports"
  fi
done < <(dc -f docker-compose.yml ps --format '{{.Name}}\t{{.Ports}}' 2>/dev/null)

if command -v lsof >/dev/null 2>&1; then
  leaked="$(lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null \
            | grep -E '(:8080|:8443|:21|:211[0-9][0-9])\b' \
            | grep -Ev '127\.0\.0\.1:' || true)"
  if [ -n "$leaked" ]; then
    bad "host sockets listening beyond loopback:"
    printf '%s\n' "$leaked" >&2
    AUDIT_FAIL=1
  fi
fi

echo
if [ "$AUDIT_FAIL" -eq 0 ]; then
  ok "bind audit clean: lab is loopback-only"
else
  bad "bind audit FAILED: something is reachable off this host, stop the lab"
fi

echo
info "catalogue state (reset with ./reset.sh if these look inflated)"
for q in \
  "products:SELECT COUNT(*) FROM products" \
  "reviews:SELECT COUNT(*) FROM reviews" \
  "orders:SELECT COUNT(*) FROM orders" \
  "sessions:SELECT COUNT(*) FROM sessions"; do
  label="${q%%:*}"; sql="${q#*:}"
  n="$(dc -f docker-compose.yml exec -T db mysql -N -uroot -p"${MYSQL_ROOT_PASSWORD:-root}" widgetorium -e "$sql" 2>/dev/null || echo '?')"
  printf '    %-10s %s\n' "$label" "$n"
done

[ "$AUDIT_FAIL" -eq 0 ] || exit 1
