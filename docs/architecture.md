# Widgetorium architecture

## Containers and network

```
                         host: 127.0.0.1 only
      ┌──────────────────────────────────────────────────────┐
      │                                                      │
  8080│ http        ┌───────────────┐                        │
  8443│ https ─────▶│    webapp     │  php:8.2-apache-bullseye│
      │             │  Apache + PHP │                        │
      │             └──────┬────────┘                        │
      │                    │ widgetorium-net (bridge)        │
      │                    │  (internal, no host route)      │
      │             ┌──────▼────────┐                        │
      │             │      db       │  mysql:8.0             │
      │             │  not published│                        │
      │             └───────────────┘                        │
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
