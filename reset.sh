#!/usr/bin/env bash
# Wipe stateful bugs back to seed: uploaded webshells, injected product rows,
# stored-XSS reviews, extra orders, harvested sessions. Rebuilds and restarts.
#   -y   skip the confirmation prompt
set -uo pipefail
cd "$(dirname "$0")"
source ./lib.sh

require_docker

if [ "${1:-}" != "-y" ]; then
  printf '%s' "Wipe all lab state (uploads, reviews, injected rows, orders, sessions) back to seed? [y/N] "
  read -r ans
  case "$ans" in y|Y|yes|YES) ;; *) info "cancelled"; exit 0 ;; esac
fi

info "down -v"
dc -f docker-compose.yml down -v

info "rebuild + up"
if ! assert_loopback_only -f docker-compose.yml; then
  bad "loopback guard failed, not restarting"
  exit 1
fi
dc -f docker-compose.yml up -d --build

info "waiting for health (up to 120s)"
deadline=$(( $(date +%s) + 120 ))
while :; do
  unhealthy="$(dc -f docker-compose.yml ps --format '{{.Name}} {{.Health}}' 2>/dev/null \
              | awk '$2 != "healthy" {print $1}')"
  [ -z "$unhealthy" ] && break
  [ "$(date +%s)" -ge "$deadline" ] && { warn "still not healthy: $unhealthy"; break; }
  sleep 3
done

ok "reset complete, lab is back to seed state"
