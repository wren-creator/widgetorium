# Changelog

All notable changes to Widgetorium are recorded here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- A fourth container, `dns` (BIND9), bound to `127.0.0.1:5300` TCP and UDP,
  authoritative for `corp.widgetorium.lab` (the internal target) and
  `widgetorium.lab` (its public face). Gives the lab a real reconnaissance
  phase: zone transfers, subdomain and vhost discovery, certificate
  inspection, worked against an actual nameserver. No public DNS, no real
  domain required. New `OPEN_AXFR` toggle.
- A **Reconnaissance** scenario category (bugs 20-24) in `docs/scenarios.md`
  and the trainee copy: open DNS zone transfer, virtual-host discovery of the
  internal apps, a TLS certificate whose SAN list leaks the internal hostname
  inventory, a developer sandbox full of `phpinfo` / notes / `.sql.bak`
  leftovers, and an S3-style export bucket with document metadata.
- Internal virtual hosts on the existing webapp container
  (`webapp/vhosts/{admin,dev,staging}`): an admin console, a developer
  sandbox, and a staging copy of the shop, reachable only by `Host` header /
  SNI. The default vhost is unchanged, so every existing scenario still works.
- A third TLS certificate (`corp.crt`, from `webapp/certs/openssl-corp.cnf`)
  served on the internal vhosts, with a SAN list that enumerates internal
  hostnames including several not present in DNS.
- A short, opt-in support-the-lab note beneath the login form
  (`webapp/src/login.php`), pointing at the developer fund
  (Cash App `$britleywren`). Plain styled aside in the Factory Tour
  theme, no popup or modal, no functional change to the lab.

### Changed
- *Widgetorium 101* is now a seven-session syllabus: a new Session 2,
  "Reconnaissance and the Corporate Domain", covers the AXFR, vhost discovery,
  the certificate SAN leak, and the dev-sandbox leftovers. The later sessions
  renumber (SQL injection is Session 3, the capstone is Session 7), the capstone
  opens with a "starting cold" recon pass, and the front matter, toolbox, and
  counts are updated. Rebuilt `docs/Widgetorium-101-Syllabus.epub`;
  `build-epub.sh` now also excludes nested dotfiles from the archive.
- `webapp/apache/000-default.conf` and `default-ssl.conf` are now multi-vhost:
  the storefront stays the default (unmatched `Host`, bare IP), with the
  internal hosts layered on by name. `docker-entrypoint.sh` and `gen-certs.sh`
  place the new `corp` certificate. `setup.sh` / `start.sh` / `status.sh` learn
  about port 5300, including the loopback bind audit. `docs/architecture.md`,
  `docs/verification.md` and the README track the four-container layout and the
  24-bug count.
- Storefront reskinned as "The Factory Tour": a whimsical widget emporium
  crossed with a mail-order novelty catalogue (Willy Wonka meets ACME Corp).
  Marquee header with a candy-stripe awning, a rotating "golden ticket"
  featured product, ticket-stub cards with a `GUARANTEED*` stamp, and a
  hazard-stripe footer. Pure CSS and markup, no web fonts (the lab has no
  egress), no functional change to the lab.

## [0.1.0] - 2026-09-02

First public release.

### Added
- Initial scaffold: `docker-compose.yml` with `webapp` (PHP 8 + Apache),
  `db` (MySQL 8), and `ftp` (vsftpd) on an internal bridge network, all host
  ports bound to `127.0.0.1`.
- 19 planted vulnerabilities across SQL injection, TLS/certificate handling,
  general web, and FTP.
- `docs/scenarios.md` instructor answer key and `docs/scenarios-trainee.md`
  trainee copy.
- Lifecycle scripts `setup.sh`, `start.sh`, `stop.sh`, `status.sh`, `reset.sh`,
  with a loopback-only guard in `start.sh` and a bind audit in `status.sh`.
- `docs/zap/` ZAP automation-framework plan and wrapper.
- `docker-compose.expired-cert.yml` override for the expired-certificate scenario.
- *Widgetorium 101*, a six-session course syllabus, as an EPUB
  (`docs/Widgetorium-101-Syllabus.epub`) with source under `docs/syllabus-epub/`.

## Project status

Widgetorium is a training lab, not a product. The bug set, container layout, and
default ports may change between revisions. Reset the lab between cohorts, several
bugs are stateful.
