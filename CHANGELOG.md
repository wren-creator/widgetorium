# Changelog

All notable changes to Widgetorium are recorded here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Changed
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
