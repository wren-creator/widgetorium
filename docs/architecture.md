# Widgetorium architecture

## Containers and network

```
                         host: 127.0.0.1 only
      ┌──────────────────────────────────────────────────────┐
      │                                                      │
  8080│ http        ┌───────────────┐                        │
  8443│ https ─────▶│    webapp     │  php:8.2-apache-bullseye│
      │             │  Apache + PHP │  default vhost = store; │
      │             │               │  admin/dev/staging by   │
      │             └──────┬────────┘  Host header / SNI      │
      │                    │ widgetorium-net (bridge)        │
      │                    │  (internal, no host route)      │
      │             ┌──────▼────────┐                        │
      │             │      db       │  mysql:8.0             │
      │             │  not published│                        │
      │             └───────────────┘                        │
      │                                                      │
  5300│ dns   ─────▶┌───────────────┐  ubuntu/bind9 9.18     │
  tcp+udp           │      dns      │  corp.widgetorium.lab  │
      │             └───────────────┘  + widgetorium.lab     │
      │                                                      │
  21  │ ftp   ─────▶┌───────────────┐  debian:12 + vsftpd    │
 21100│ pasv        │      ftp      │                        │
 -21110            └──────┬────────┘                        │
      │                    │                                 │
      └────────────────────┼─────────────────────────────────┘
                           │
              widgetorium-dropzone (named volume)
        webapp:/var/www/html/uploads/ftp  ==  ftp:/srv/ftp/upload
```

- **All published ports bind to `127.0.0.1`.** `start.sh` refuses to launch
  otherwise; `status.sh` audits the running bindings. The bridge network is not
  marked `internal: true` because on several Docker releases that also suppresses
  host port publishing. If your Docker publishes ports correctly with
  `internal: true`, adding it is a reasonable extra hardening step, test it.
- **`db` publishes nothing.** sqlmap and `LOAD_FILE` exercises go through the
  webapp HTTP surface. There is no direct DB socket on the host.
- **`dns` publishes `127.0.0.1:5300`, TCP and UDP.** Port 53 is the host
  resolver's and 5353 is mDNS on macOS, so the lab uses 5300 and the tooling
  (`dig -p 5300`, `dnsrecon -p 5300`, `status.sh`) points at it. The container
  runs as root only so `named` can bind the pid file and rndc key, then drops
  to the `bind` user; the entrypoint copies the read-only config mounts to a
  writable path and applies `OPEN_AXFR` before starting.
- **Shared dropzone** is a named volume, not a bind mount, so `./reset.sh`
  (`down -v`) actually clears planted webshells and nothing lands in git.

## Volumes

| Volume | Mounted at | Purpose |
|---|---|---|
| `widgetorium-db-data` | `db:/var/lib/mysql` | MySQL data. Wiped by `stop.sh --all` / `reset.sh`. |
| `widgetorium-dropzone` | `webapp:/var/www/html/uploads/ftp`, `ftp:/srv/ftp/upload` | the FTP-to-webshell chain (bug 19). |

Bind mounts (read-only): `db/init.sql`, `db/my.cnf`, `db/loot/secret.txt`.

## Toggles

Read from `.env` (created from `.env.example` by `setup.sh`). Every one defaults
to the "vulnerable" value if `.env` is absent.

| Var | Bug | `1` (default) | `0` |
|---|---|---|---|
| `WEAK_TLS` | 7 | TLS 1.0/1.1 + RC4/3DES/EXPORT | system default TLS |
| `SEND_HSTS` | 8 | *(default 0)* header omitted | HSTS header sent |
| `EXPIRED_CERT` | 6 | *(default 0)* self-signed mismatch | expired 2019 cert |
| `VERBOSE_ERRORS` | 14 | SQL + trace in responses | generic error page |
| `SECOND_ORDER_SINK` | 3 | report concatenates stored names | `PDO::quote` variant |
| `WEAK_SESSIONS` | 13 | `hex(time)+hex(id)` token | `random_bytes` token |
| `PLANT_GIT` | 9 | `/admin/.git` served | directory removed at boot |
| `OPEN_AXFR` | 20 | `corp.widgetorium.lab` transfer open to anyone | transfer refused |

## Known quirks

- **Weak-TLS finding set (bug 7).** The `php:8.2-apache-bullseye` base ships
  OpenSSL 1.1.1 but Debian builds it without RC4, 3DES and EXPORT ciphers, so
  those cannot be offered regardless of config. What the lab does deliver:
  TLS 1.0 and 1.1 enabled, SHA1 CBC ciphers (`AES128-SHA`, `AES256-SHA`)
  accepted at `@SECLEVEL=0`, and 1024-bit DH parameters. That is the realistic
  profile of a legacy deployment and is what testssl.sh will flag.
- **vsftpd anonymous segfault.** vsftpd 3.0.x on this Alpine/arm64 build
  occasionally segfaults its session process on an anonymous connection under
  rapid concurrent load (roughly one in a few hundred). `restart:
  unless-stopped` brings it back in about a second, and `isolate=NO` /
  `hide_ids=YES` in `vsftpd.conf` keep it rare. Real training use (a handful of
  FTP commands per exercise) will effectively never hit it; a machine-gun
  scanner might. The healthcheck deliberately checks the process
  (`pgrep vsftpd`) rather than opening a socket, because the zero-byte
  half-open probe that `nc -z` makes is itself a reliable trigger.

## The reconnaissance surface

Everything the recon category (bugs 20-24) touches is static, no state, no
reset needed.

### DNS (`dns/`)

Two zones on one authoritative BIND9 instance, no recursion:

- **`corp.widgetorium.lab`** is the internal target. `allow-transfer { any; }`
  (bug 20) means one `dig axfr` dumps it. It holds the live vhost names
  (`www`, `shop`, `admin`, `api`, `dev`, `staging`, `legacy`, `ftp`, all
  `A 127.0.0.1`), a wildcard so every guessed name still resolves (which is why
  subdomain brute forcing by resolution is useless and vhost fuzzing is not),
  stale records into `10.10.0.0/16` that resolve but never answer, and
  SPF/DMARC/TXT/MX strings.
- **`widgetorium.lab`** is the public face. `allow-transfer { none; }`, a
  short record set, and an `NS` delegation for `corp` that is the breadcrumb
  from the outside zone to the inside one.

`OPEN_AXFR=0` rewrites the `corp` transfer rule to `{ none; }` at container
start (the entrypoint seds the line tagged `BUG20_AXFR`).

### Virtual hosts (`webapp/vhosts/`)

`webapp/apache/000-default.conf` lists the storefront vhost **first**, so a
request with no `Host`, a bare IP, or an unknown `Host` lands on the shop and
every pre-existing scenario is unaffected. `admin`, `dev` and `staging`
`.corp.widgetorium.lab` follow as exact-name vhosts with their own document
roots under `/var/www/vhosts/`; an exact `Host` match wins over the default even
though it is listed later. The `:443` side (`default-ssl.conf`) mirrors this by
SNI, with the weak-TLS directives hoisted into server context so all four
vhosts inherit them.

### Certificates (`webapp/certs/`)

`gen-certs.sh` now emits a third pair, `corp.crt` / `corp.key`, from
`openssl-corp.cnf`. Its `subjectAltName` lists thirteen names, four of them
(`git`, `jenkins`, `vault`, `registry`) not in the DNS zone at all. The default
`:443` vhost still serves the bug-5 cert (CN `widget-store-prod-01`, no SAN), so
which certificate a client gets is decided by the SNI name it sends. That is
bug 22: the TLS handshake leaks the host inventory even with the AXFR closed.

### Leftovers (`webapp/vhosts/dev`, `webapp/vhosts/admin`, `webapp/vhosts/staging`)

Bugs 23 and 24 are just files in a document root with directory listing on:
`phpinfo.php`, `notes/dev-notes.txt`, `.well-known/security.txt`, a `robots.txt`
full of hints, an `admin` `/backup/users-*.sql.bak` with the real MD5 hashes, a
staging `config.php.bak` and `build-info.json`, and an `s3/` directory serving a
fake `ListBucketResult` plus a metadata-laden PDF, a staff CSV, and a small
gzipped SQL sample. The PDF is generated once by `webapp/tools/make-recon-pdf.py`
and committed; rerun that script to change its contents or metadata.

## The three bugs worth explaining in detail

### Bug 3: second-order SQL injection

Two code paths that never meet in a single request:

1. `webapp/src/admin/products.php` writes the product name through a **bound
   parameter**. Quotes and SQL metacharacters are stored byte-for-byte in
   `products.name` (a `VARCHAR(255)`, sized to hold a full UNION payload).
   Nothing executes. No scanner sees anything.
2. `webapp/src/admin/inventory_report.php` iterates the stored names and builds
   a fresh query per product:
   `SELECT COALESCE(SUM(delta),0) FROM stock_ledger WHERE label = '<name>'`.
   The stored payload fires here and its result prints in the "on hand" column.

ZAP active-scans the form and the report separately and never links them. The
lesson: data already in your database is still untrusted input.

### Bug 9: planted `.git` history

`webapp/tools/plant-git.sh` runs at image build time inside
`/var/www/html/admin`:

- commit 1 (`2024-11-02`): `config.php` with
  `WIDGETORIUM_API_KEY = 'wdg_live_sk_...'` in cleartext.
- commit 2 (`2024-11-04`): `config.php` rewritten to read the key from the
  environment. The working tree is now clean; the key lives only in history.

Author and committer dates are fixed, so the commit hashes are identical across
rebuilds. `apache/dotfiles-allow.conf` re-grants access to the `.git` path and
turns on directory listing so both git-dumper modes and a manual gobuster walk
work. `.gitignore` also lists `webapp/src/admin/.git/` so a stray local run of
the script cannot commit a nested repo.

### Bug 13: predictable session tokens

`webapp/src/lib/session.php`, when `WEAK_SESSIONS=1`:

```
token = dechex(time()) . str_pad(dechex(user_id), 4, '0', STR_PAD_LEFT)
```

The `WIDGET_SESSID` cookie is the entire auth identity; a row goes in the
`sessions` table and `wdg_current_user()` looks the user up by token. PHP's
native session is only used for incidental state. Because the token is
`hex(unix_time) . hex(user_id)`, seeing one token (or knowing a rough login
time) lets an attacker enumerate a few hundred candidates for a target
`user_id`, and `user_id` 1 is the admin. With `WEAK_SESSIONS=0` the token is 24
random bytes and the attack is off the table.
