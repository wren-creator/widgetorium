# Changelog

All notable changes to Widgetorium are recorded here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

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

## Project status

Widgetorium is a training lab, not a product. The bug set, container layout, and
default ports may change between revisions. Reset the lab between cohorts, several
bugs are stateful.
