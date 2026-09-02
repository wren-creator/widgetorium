#!/usr/bin/env bash
# Run the ZAP baseline against a running Widgetorium.
#
# ZAP is NOT a compose service. This wrapper runs the official ZAP image
# on-demand, joined to the widgetorium-net network so it can reach the app by
# its service name as http://webapp (port 80 inside the network).
#
# Output: docs/zap/out/report.html and report.json
#
# Requires the lab to be up (./start.sh).
set -euo pipefail
cd "$(dirname "$0")"

# Pinned to a specific ZAP release. For a stronger guarantee, resolve this tag
# to a digest on your host and export it:
#   ZAP_IMAGE="zaproxy/zap-stable@sha256:<digest>" docs/zap/run-zap.sh
ZAP_IMAGE="${ZAP_IMAGE:-zaproxy/zap-stable:2.15.0}"
echo "[run-zap] image: $ZAP_IMAGE"

NETWORK="${WIDGETORIUM_NET:-widgetorium-net}"
if ! docker network inspect "$NETWORK" >/dev/null 2>&1; then
  echo "[run-zap] network $NETWORK not found. Start the lab first: ./start.sh" >&2
  exit 1
fi

mkdir -p out

docker run --rm \
  --network "$NETWORK" \
  -v "$PWD/widgetorium-zap-plan.yaml:/zap/wrk/plan.yaml:ro" \
  -v "$PWD/out:/zap/wrk/out" \
  "$ZAP_IMAGE" \
  zap.sh -cmd -autorun /zap/wrk/plan.yaml

echo "[run-zap] done. Report: docs/zap/out/report.html"
