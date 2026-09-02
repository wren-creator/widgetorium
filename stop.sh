#!/usr/bin/env bash
# Stop the lab.
#   (no args)     stop containers, keep the volumes
#   --all | -v    also remove the named volumes (wipes DB + dropzone)
set -uo pipefail
cd "$(dirname "$0")"
source ./lib.sh

case "${1:-}" in
  --all|-v)
    warn "removing containers AND volumes (DB data + FTP dropzone)"
    dc -f docker-compose.yml down -v
    ok "lab stopped, volumes removed"
    ;;
  *)
    dc -f docker-compose.yml down
    ok "lab stopped, volumes kept"
    ;;
esac
