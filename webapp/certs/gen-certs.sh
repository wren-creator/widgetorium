#!/usr/bin/env bash
# Generate the lab's TLS material. Run at image build time; also safe to run
# by hand from setup.sh if you want to inspect the certs locally.
#
# Outputs (all git-ignored):
#   selfsigned.crt / selfsigned.key  - vuln 5: CN does not match the hostname,
#                                      no subjectAltName at all
#   expired.crt   / expired.key      - vuln 6: valid window entirely in 2019
#   dhparam-1024.pem                 - vuln 7: weak DH parameters
set -euo pipefail

cd "$(dirname "$0")"

SUBJ="/C=GB/ST=Somewhere/L=Nowhere/O=Widgetorium Retail Ltd/OU=IT/CN=widget-store-prod-01"

echo "[gen-certs] self-signed certificate with a mismatched CN and no SAN"
openssl req -x509 -newkey rsa:2048 -nodes -days 825 \
    -keyout selfsigned.key -out selfsigned.crt \
    -subj "$SUBJ"

echo "[gen-certs] expired certificate (notBefore/notAfter both in 2019)"
if command -v faketime >/dev/null 2>&1; then
    faketime '2019-01-01 00:00:00' \
        openssl req -x509 -newkey rsa:2048 -nodes -days 30 \
            -keyout expired.key -out expired.crt \
            -subj "$SUBJ"
else
    # Fallback for OpenSSL >= 1.1.1h without faketime.
    echo "[gen-certs] faketime not found, using openssl -not_before/-not_after"
    openssl req -x509 -newkey rsa:2048 -nodes \
        -not_before 20190101000000Z -not_after 20190131000000Z \
        -keyout expired.key -out expired.crt \
        -subj "$SUBJ"
fi

echo "[gen-certs] 1024-bit DH parameters"
openssl dhparam -out dhparam-1024.pem 1024

echo "[gen-certs] done:"
ls -l selfsigned.crt selfsigned.key expired.crt expired.key dhparam-1024.pem
