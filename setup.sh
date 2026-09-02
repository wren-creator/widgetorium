#!/usr/bin/env bash
# One-time setup: preflight checks, build images, pull the DB image.
# Safe to re-run.
set -uo pipefail
cd "$(dirname "$0")"
source ./lib.sh

require_docker

info "checking host ports 8080, 8443, 21, 21100-21110"
BUSY=0
for p in 8080 8443 21 21100 21105 21110; do
  if lsof -nP -iTCP:"$p" -sTCP:LISTEN >/dev/null 2>&1; then
    warn "port $p is already in use"
    BUSY=1
  fi
done
[ "$BUSY" -eq 0 ] && ok "ports are free" || warn "free the ports above or the lab will not bind"

if [ ! -f .env ]; then
  cp .env.example .env
  ok "created .env from .env.example"
else
  info ".env already present, leaving it alone"
fi

info "verifying nothing would bind beyond 127.0.0.1"
if assert_loopback_only -f docker-compose.yml; then
  ok "loopback-only bindings confirmed"
else
  bad "compose config check failed"
  exit 1
fi

info "building images (this generates the lab certs and plants the .git history)"
dc -f docker-compose.yml build
dc -f docker-compose.yml pull db

ok "setup complete"
echo
echo "  next:  ./start.sh          bring the lab up"
echo "         ./status.sh         health + loopback audit"
echo "         docs/verification.md   per-bug test runbook"
