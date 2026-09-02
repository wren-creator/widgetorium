#!/usr/bin/env bash
# Bring the lab up. Refuses to launch if any published port would bind beyond
# 127.0.0.1.
#   --expired-cert   run the expired-certificate scenario (vuln 6)
set -uo pipefail
cd "$(dirname "$0")"
source ./lib.sh

COMPOSE_ARGS=(-f docker-compose.yml)
if [ "${1:-}" = "--expired-cert" ]; then
  COMPOSE_ARGS+=(-f docker-compose.expired-cert.yml)
  info "expired-certificate scenario selected"
fi

require_docker

info "loopback-only guard"
if ! assert_loopback_only "${COMPOSE_ARGS[@]}"; then
  bad "not starting"
  exit 1
fi
ok "all published ports bind to 127.0.0.1"

info "starting containers"
dc "${COMPOSE_ARGS[@]}" up -d

info "waiting for health (up to 120s)"
deadline=$(( $(date +%s) + 120 ))
while :; do
  unhealthy="$(dc "${COMPOSE_ARGS[@]}" ps --format '{{.Name}} {{.Health}}' 2>/dev/null \
              | awk '$2 != "healthy" {print $1}')"
  [ -z "$unhealthy" ] && break
  if [ "$(date +%s)" -ge "$deadline" ]; then
    warn "still not healthy: $unhealthy"
    warn "check: dc logs"
    break
  fi
  sleep 3
done

echo
ok "Widgetorium is up"
echo "  store        http://127.0.0.1:8080/"
echo "  store (TLS)  https://127.0.0.1:8443/    (certificate warning is expected)"
echo "  ftp          127.0.0.1:21               (anonymous, plus ftpuser:ftpuser)"
echo
echo "  expired-cert scenario:  ./start.sh --expired-cert"
echo "  instructor answer key:  docs/scenarios.md"
echo "  reset stateful bugs:    ./reset.sh"
