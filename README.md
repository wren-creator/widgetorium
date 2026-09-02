# Widgetorium

A deliberately vulnerable widget-shop web lab for authorised web pen-testing training.

> Use Widgetorium only: on your own machine; in a lab you control; in a classroom
> or range where you have permission; under written rules of engagement for
> authorised training or assessment. Do not use Widgetorium lab commands,
> payloads, API tests, scanning, credentials, or techniques against third-party
> systems.

## Overview

One `docker-compose.yml`, three containers (`webapp`, `db`, `ftp`) on an internal
bridge network. Every host port binds to `127.0.0.1` only, so the lab is reachable
from the machine running it and nowhere else. 19 planted bugs across SQL injection,
TLS and certificate handling, general web, and FTP, each with a documented intended
exploit path and fix in `docs/scenarios.md`.

The teaching flow is ZAP-first: ZAP does discovery for each vulnerability category,
and a per-bug spot-check tool (sqlmap, testssl.sh, gobuster, Wireshark) confirms or
exploits what ZAP surfaces. Several bugs, by design, ZAP will not find on its own,
that gap is part of the lesson.

Inspired by DVWA, OWASP Juice Shop, and WebGoat.

## Quick start

```bash
# one-time: preflight checks, build images, generate the lab certificates,
# plant the .git history
./setup.sh

# bring the lab up
#   store        http://127.0.0.1:8080/
#   store (TLS)  https://127.0.0.1:8443/   (certificate warning is expected)
#   ftp          127.0.0.1:21              (anonymous, plus ftpuser:ftpuser)
./start.sh

# health check plus a confirmation that nothing is bound beyond 127.0.0.1
./status.sh

# run the expired-certificate scenario instead of the default self-signed one
docker compose -f docker-compose.yml -f docker-compose.expired-cert.yml up -d

# wipe stateful bugs (uploads, reviews, injected rows, orders) back to seed
./reset.sh

# stop the lab, keep the data / stop and wipe the volumes
./stop.sh
./stop.sh --all
```

## Layout

| Path | Description |
|---|---|
| `docker-compose.yml` | the lab: three services, internal network, `127.0.0.1` bindings |
| `docker-compose.expired-cert.yml` | override that swaps in the expired certificate |
| `webapp/` | Apache + PHP 8 "Widgetorium" store; `webapp/src/` is the site |
| `webapp/certs/` | self-signed and expired certificate variants, and the generator |
| `ftp/` | intentionally misconfigured vsftpd; its upload dir is shared into the web root |
| `db/` | MySQL 8 schema, seed data, and the loose `secure_file_priv` config |
| `docs/scenarios.md` | instructor answer key: every bug, how ZAP finds it, spot-check tool, fix |
| `docs/scenarios-trainee.md` | trainee copy with the fix column removed |
| `docs/architecture.md` | container / network / volume layout and the tricky bug mechanics |
| `docs/verification.md` | end-to-end test runbook, including the loopback bind audit |
| `docs/zap/` | optional ZAP automation-framework plan and a wrapper script |
| `docs/syllabus-epub/` | source for *Widgetorium 101*, a six-session course syllabus |
| `docs/Widgetorium-101-Syllabus.epub` | the built syllabus ebook (rebuild with `docs/syllabus-epub/build-epub.sh`) |
| `setup.sh` `start.sh` `stop.sh` `status.sh` `reset.sh` | lifecycle scripts |

## Services and ports

| Service | Host bind | Purpose |
|---|---|---|
| webapp HTTP | `127.0.0.1:8080` | the store |
| webapp HTTPS | `127.0.0.1:8443` | TLS and certificate scenarios |
| ftp | `127.0.0.1:21` plus `21100-21110` passive | vsftpd, anonymous and `ftpuser:ftpuser` |
| db | not published | MySQL, reachable only from `webapp` on the internal network |

## Certificate variants

The default is a self-signed certificate whose CN does not match the hostname and
which carries no SAN. The expired variant is swapped in with the override file
shown in the quick start, or by setting `EXPIRED_CERT=1`. Both variants also run
with TLS 1.0/1.1 enabled and weak ciphers unless `WEAK_TLS=0`.

## Scenarios

19 planted bugs in four groups:

- **SQL injection** (4): product-search UNION injection, login auth bypass,
  second-order injection through an admin report, and an injectable plus
  unauthorised price/quantity API.
- **Certificate and TLS** (4): self-signed CN mismatch, expired certificate,
  legacy protocols and weak ciphers, missing HSTS.
- **Other web** (6): exposed `/admin/.git/` with a secret in history, IDOR on
  order history, reflected and stored XSS in reviews, unrestricted file upload
  with path traversal, predictable session tokens, verbose error messages.
- **FTP** (5): anonymous login with write access, weak service credentials,
  chroot escape, cleartext credentials, and the FTP-upload-to-webshell chain.

Trainees work from `docs/scenarios-trainee.md`. Instructors hold
`docs/scenarios.md`, which adds the intended exploit path and the fix for each bug.

## Course

*Widgetorium 101* is a six-session syllabus built on this lab: orientation and the
ZAP baseline, SQL injection four ways, certificates and transport security, the
web application grab bag, the FTP box, and a chaining capstone. The ebook is at
`docs/Widgetorium-101-Syllabus.epub`; the source is under `docs/syllabus-epub/`
and rebuilds with `docs/syllabus-epub/build-epub.sh`.

## Security and authorised use

Widgetorium contains deliberately vulnerable behaviour, crackable credentials, and
a live webshell-drop path, for teaching.

Use Widgetorium only: on your own machine; in a lab you control; in a classroom or
range where you have permission; under written rules of engagement for authorised
training or assessment. Do not use Widgetorium lab commands, payloads, API tests,
scanning, credentials, or techniques against third-party systems.

It is strictly local. Host ports bind to `127.0.0.1` only. `start.sh` refuses to
launch if any published port would bind beyond loopback, and `status.sh` audits the
running bindings. Keep the host offline or firewalled while the lab is up. Never
deploy Widgetorium to a shared, routable, or cloud network.

## Verification

See `docs/verification.md` for per-bug confirmation commands and the check that
confirms nothing is bound beyond `127.0.0.1`.

## Project status

Training lab. The bug set and the layout may change between revisions. See
`CHANGELOG.md`.

## Credits

Inspired by DVWA, OWASP Juice Shop, and WebGoat. Repo conventions follow the
sibling projects Hack3270, EZrecon-2, GIBSON, and DVCA.

## Acknowledgements

Built for an authorised internal web pen-testing training series.

## Licence

GPL-3.0-or-later, see [`LICENSE`](LICENSE).
